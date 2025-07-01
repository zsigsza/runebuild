package runebuild
import "shared:ini"

build_command :: proc(args: []string) {
	if !config_exists() {
		config_not_valid()
		return
	}

	if len(args) < 1 {
		not_specified()
		return
	}

	type := args[0]

	is_debug := false

	switch type {
	case "debug":
		is_debug = true
	case "release":
		break
	case:
		is_not_an_option(type)
		return
	}

	ini_file, success := ini.parse(CONFIG_PATH)
	defer if success do ini.destroy(ini_file)

	if !success {
		panic("Cant read ini file.")
	}

	compile_shaders(is_debug, ini_file)
	compile_project(is_debug, ini_file, false)
}
