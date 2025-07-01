package runebuild
import "core:fmt"

help_command :: proc(args: []string) {
	fmt.println("The Odin and BGFX build system")
	fmt.println()

	fmt.println("Usage:")
	fmt.printfln("\t{0} [command] [args...]", PROGRAM_NAME)
	fmt.println()

	fmt.println("Flags:")
	fmt.println("\t-usage or -u\t Displays command usage.")
	fmt.println()

	fmt.println("Commands:")
	for command in storage.commands {
		fmt.printfln("\t{0}\t\t{1}", command.trigger, command.description)
	}
}
