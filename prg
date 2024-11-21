#include <windows.h>
#include <iostream>
#include <string>
#include <vector>
#include <sstream>
using namespace std;

#define RANGE 1000   
#define NUM_PROCESSES 10
#define BUFFER_SIZE 256


bool isPrime(int num) {
    if (num < 2) return false;
    for (int i = 2; i * i <= num; ++i) {
        if (num % i == 0) return false;
    }
    return true;
}

void findPrimesInRange(int start, int end, HANDLE writePipe) {
    ostringstream result;
    for (int i = start; i <= end; i++) {
        if (isPrime(i)) {
            result << i << " ";
        }
    }
    result << "*"<<endl;

    string output = result.str();
    DWORD bytesWritten;
    WriteFile(writePipe, output.c_str(), output.size(), &bytesWritten, NULL);
    CloseHandle(writePipe);  
}

int main(int argc, char* argv[]) {
    if (argc == 3) {
        int start = stoi(argv[1]);
        int end = stoi(argv[2]);

        HANDLE writePipe = GetStdHandle(STD_OUTPUT_HANDLE);  
        findPrimesInRange(start, end, writePipe);
        return 0;
    }

    
    HANDLE pipes[NUM_PROCESSES][2];
    HANDLE writePipes[NUM_PROCESSES];
    HANDLE readPipes[NUM_PROCESSES];

    
    for (int i = 0; i < NUM_PROCESSES; i++) {
        SECURITY_ATTRIBUTES sa = { sizeof(SECURITY_ATTRIBUTES), NULL, TRUE };  
        if (!CreatePipe(&pipes[i][0], &pipes[i][1], &sa, 0)) {
            return 1;
        }
        readPipes[i] = pipes[i][0];
        writePipes[i] = pipes[i][1];
    }

  
    for (int i = 0; i < NUM_PROCESSES; i++) {
        int start = i * RANGE + 1;
        int end = (i + 1) * RANGE;

        HANDLE childWritePipe;
        DuplicateHandle(GetCurrentProcess(), writePipes[i], GetCurrentProcess(), &childWritePipe, 0, TRUE, DUPLICATE_SAME_ACCESS);

        string command = string(argv[0]) + " " + to_string(start) + " " + to_string(end);
        char cmdLine[BUFFER_SIZE];
        strcpy_s(cmdLine, command.c_str());

         PROCESS_INFORMATION pi;
        STARTUPINFO si = { sizeof(STARTUPINFO) };
        si.dwFlags = STARTF_USESTDHANDLES;
        si.hStdOutput = childWritePipe; 

        if (!CreateProcess(NULL, cmdLine, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
            return 1;
        }

        CloseHandle(childWritePipe);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
    }


    cout << "Numerele prime pana la 10,000:\n";
    char buffer[BUFFER_SIZE];
    for (int i = 0; i < NUM_PROCESSES; i++) {
        CloseHandle(writePipes[i]);  
        DWORD bytesRead;
        cout << " \nDatele primite de la procesul " << i + 1 << "...\n";
        while (ReadFile(readPipes[i], buffer, BUFFER_SIZE - 1, &bytesRead, NULL) && bytesRead > 0) {
            buffer[bytesRead] = '\0';
            cout << buffer;
            if (std::string(buffer).find("*") != string::npos) break;
        }
        CloseHandle(readPipes[i]); 
    }

    return 0;
}
