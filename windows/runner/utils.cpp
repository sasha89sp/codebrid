#include "utils.h"

#include <windows.h>

#include <io.h>
#include <stdio.h>
#include <fcntl.h>

#include <shellapi.h>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE* unused;
    freopen_s(&unused, "CONIN$", "r", stdin);
    freopen_s(&unused, "CONOUT$", "w", stdout);
    freopen_s(&unused, "CONOUT$", "w", stderr);
    ::SetConsoleOutputCP(CP_UTF8);
  }
}

std::vector<std::string> GetCommandLineArguments() {
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) return {};

  std::vector<std::string> command_line_arguments;
  for (int i = 1; i < argc; i++) {
    int size = ::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, argv[i], -1,
                                     nullptr, 0, nullptr, nullptr);
    if (size > 0) {
      std::string argument(size, '\0');
      ::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, argv[i], -1,
                            argument.data(), size, nullptr, nullptr);
      argument.pop_back();
      command_line_arguments.push_back(argument);
    }
  }
  ::LocalFree(argv);
  return command_line_arguments;
}
