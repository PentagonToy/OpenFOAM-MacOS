#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSString *command = @"OpenFOAM-14.command";
        NSString *executable = NSProcessInfo.processInfo.arguments.firstObject;
        if ([executable.lastPathComponent isEqualToString:command]) {
            NSString *launcher = [[executable.stringByDeletingLastPathComponent
                stringByAppendingPathComponent:@"../Resources/openfoam-14"] stringByStandardizingPath];
            execv(launcher.fileSystemRepresentation, argv);
            perror("openfoam-14");
            return 1;
        }

        NSString *launcher = [NSBundle.mainBundle pathForAuxiliaryExecutable:command];
        if (launcher == nil) {
            fputs("The OpenFOAM 14 Terminal launcher is missing.\n", stderr);
            return 1;
        }

        char *const arguments[] = {
            "open", "-a", "Terminal", (char *)launcher.fileSystemRepresentation, NULL
        };
        execv("/usr/bin/open", arguments);
        perror("open");
        return 1;
    }
}
