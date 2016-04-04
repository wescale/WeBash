# WeBash
Harden your bash scripts with WeBash

WeBash is a shell script library which tries to enforce the Unofficial Bash Strict Mode and provides a couple of nice features:
* Stacktrace: If your scripts exits, a stack trace will be displayed, showing the execution path of your script.
* Logging policies: By default, your script will log on stdout if you execute it from a terminal, otherwise a log file will be created, showing the whole execution. You can customize this behavior by forcing to create a log file even if you are calling the script from your terminal. You can also decide if you want the logfile to be recreated each time, or if you prefer to append new logs to the existing log file (default).
