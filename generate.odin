package runebuild
import "core:fmt"
import "core:os"
import "core:os/os2"
import sp "core:path/slashpath"

default := #load("default.ini")
proj_default := #load("proj_default.ini")
example_main := #load("example_main")

generate_command :: proc(args: []string) {
	if len(args) < 1 {
		fmt.println("Type was not specified.")
		return
	}

	type := args[0]

	current_dir := os.get_current_directory()
	switch type {
	case "config":
		gen_config(false)
	case "project":
		gen_config(true)
		os2.make_directory("src")
		os2.make_directory("shaders")
		err := os2.write_entire_file("src/main.odin", example_main)
		if err != nil {
			fmt.println("Could not write main.odin file.")
		}
	case:
		is_not_an_option(type)
	}
}

gen_config :: proc(project: bool) {
	if config_exists() {
		fmt.println("There is already a project config file in this folder.")
		return
	}

	if !os.write_entire_file(CONFIG_PATH, project ? proj_default : default) {
		fmt.println("Error writing config!")
		return
	} else {
		fmt.println("Created config file. Make sure to fill in the empty fields!")
	}
}
