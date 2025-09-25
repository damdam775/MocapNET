#pragma once

#include "windows_compat.h"

#ifdef _WIN32
#define NORMAL ""
#define BLACK  ""
#define RED    ""
#define GREEN  ""
#define YELLOW ""
#else
#define NORMAL   "\033[0m"
#define BLACK   "\033[30m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#endif
