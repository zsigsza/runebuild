package runebuild

import "core:fmt"
import "core:os/os2"
import "core:path/slashpath"
import "core:strings"
import "shared:ini"

os_enum_to_string :: proc() -> string {
	if ODIN_OS == .Windows {
		return "windows"
	} else if ODIN_OS == .Linux {
		return "linux"
	} else if ODIN_OS == .Darwin {
		return "darwin"
	}
	panic("Not supported")
}

compile_project :: proc(is_debug: bool, ini_file: ^ini.Ini_File, do_run: bool) {
	os2.remove_all(globalConfig.export_dir)
	for build_target in globalConfig.build_targets {
		run := false
		if strings.contains(build_target, os_enum_to_string()) {
			run = true && do_run
		}

		compiler_flags: []string
		val, ok := ini.get(
			ini_file,
			strings.join({"build-rule-", build_target}, ""),
			"compiler_flags",
			string,
		)

		if ok {
			compiler_flags = strings.split(val, ",")
		}


		final_command: [dynamic]string

		out_folder := slashpath.join(
			{globalConfig.export_dir, build_target, is_debug ? "debug" : "release"},
		)

		exe_name: string

		if strings.contains(build_target, "windows") {
			exe_name = strings.join({globalConfig.project_export_name, ".exe"}, "")
		} else {
			exe_name = strings.join({globalConfig.project_export_name, ".out"}, "")
		}

		os2.make_directory_all(out_folder)

		append(&final_command, "odin")

		if run {
			append(&final_command, "run")
		} else {
			append(&final_command, "build")
		}

		append(&final_command, globalConfig.project_dir)

		if is_debug {
			append(&final_command, "-debug")
		}

		append(&final_command, strings.join({"-out:", slashpath.join({out_folder, exe_name})}, ""))
		append(&final_command, strings.join({"-target:", build_target}, ""))

		append(&final_command, ..compiler_flags)


		desc := os2.Process_Desc {
			command = final_command[:],
		}

		state, stdout, stderr, _ := os2.process_exec(desc, context.allocator)
		if len(stderr) > 0 {
			fmt.printfln("Error while compiling project for {0}", build_target)
			fmt.println(strings.clone_from_bytes(stderr))
			fmt.println("--------------------------------------------------")
		}
	}


}
