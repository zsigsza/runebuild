package runebuild
import "core:fmt"

is_not_an_option :: proc(str: string) {
	fmt.printfln("\"{0}\" is not an option.", str)
}
not_specified :: proc() {
	fmt.println("Type was not specified.")
}

config_not_valid :: proc() {
	fmt.printfln(
		"Config is not valid, please check it, if there is one. Use \"{0} gen config\" to create a new config.",
		PROGRAM_NAME,
	)
}

is_empty :: proc(str: string) {
	fmt.printfln("\"{0}\" is empty, please check your config!", str)
}
