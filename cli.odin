package runebuild

import "base:runtime"
import "core:fmt"
import "core:os"

callback :: #type proc(args: []string)

CommandStorage :: struct {
	commands: [dynamic]Command,
}

Command :: struct {
	trigger:     string,
	usage:       string,
	description: string,
	callback:    callback,
}

add_command :: proc(storage: ^CommandStorage, command: Command) {
	append(&storage.commands, command)
}

parse :: proc(storage: CommandStorage, args: []string) {
	if len(args) <= 0 {
		fmt.printfln(
			"No args were supplied. Use \"{0} help\" for a list of commands.",
			PROGRAM_NAME,
		)
		return
	}
	trigger := args[0]

	found_usage_flag := false


	for arg in args {
		switch arg {
		case "-u", "-usage":
			found_usage_flag = true
		}
	}

	found := false
	for stored_command in storage.commands {
		if stored_command.trigger != trigger {
			continue
		}
		found = true

		if found_usage_flag {
			fmt.printfln("{0} {1} {2}", PROGRAM_NAME, trigger, stored_command.usage)
			break
		}

		if len(args) >= 2 {
			stored_command.callback(args[1:])
		} else {
			stored_command.callback({})
		}
		break
	}

	if !found {
		fmt.printfln("No command named \"{0}\".", trigger)
	}
}
