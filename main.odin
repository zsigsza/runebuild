package runebuild
import "core:fmt"
import "core:os"
import "core:path/filepath"
import sp "core:path/slashpath"
import "core:slice"
import "core:strings"
import "shared:ini"

PROGRAM_NAME :: "runebuild"
PROGRAM_VERSION :: "1.0.0"

CONFIG_PATH := sp.join({os.get_current_directory(), "project.ini"})

Config :: struct {
	bgfx_folder:         string,
	project_dir:         string,
	export_dir:          string,
	shader_in_dir:       string,
	shader_out_dir:      string,
	shader_targets:      []string,
	shader_versions:     []string,
	shader_includes:     []string,
	generate_dir:        string,
	project_export_name: string,
	bgfx_deps_target:    string,
	build_targets:       []string,
	version_major:       u32,
	version_minor:       u32,
	version_patch:       u32,
	valid:               bool,
}

globalConfig := Config{}
storage := CommandStorage{}

main :: proc() {
	globalConfig.valid = verify_config()
	if globalConfig.valid {
		init_config()
	}

	add_command(&storage, Command{"help", "", "Shows this help menu.", help_command})
	add_command(&storage, Command{"version", "", "Shows the tool version.", version_command})
	add_command(
		&storage,
		Command{"gen", "[config/project]", "Generate project files.", generate_command},
	)
	add_command(
		&storage,
		Command{"build", "[debug/release]", "Build project as an executable.", build_command},
	)
	add_command(
		&storage,
		Command{"run", "[debug/release]", "Run project as an executable.", run_command},
	)
	parse(storage, os.args[1:])
}

verify_config :: proc() -> bool {
	if !config_exists() {return false}

	ini_file, ini_ok := ini.parse(CONFIG_PATH)
	defer if ini_ok do ini.destroy(ini_file)

	if !ini_ok {
		fmt.println("Error parsing project config file.")
		return false
	}

	ini.add_parser(ini_file, u32, parse_u32)

	bgfx_folder, bgfx_folder_ok := ini.get(ini_file, "dev-dependencies", "bgfx_folder", string)
	bgfx_deps_target, bgfx_deps_target_ok := ini.get(
		ini_file,
		"dev-dependencies",
		"bgfx_deps_target",
		string,
	)

	if len(bgfx_folder) == 0 || !bgfx_folder_ok {
		fmt.println(
			"\"bgfx_folder\" is empty, you may have forgotten to add the BGFX path after generating the config.",
		)
	}

	if len(bgfx_deps_target) == 0 || !bgfx_deps_target_ok {
		fmt.println(
			"\"bgfx_deps_target\" is empty, you may have forgotten to add the BGFX path after generating the config.",
		)
	}

	get :: proc(file: ^ini.Ini_File, section: string, key: string, $T: typeid) -> bool {
		v, ok := ini.get(file, section, key, T)

		if !ok {
			fmt.printfln("\"{0}\" at [{1}] is invalid!", key, section)
		}

		return ok
	}

	project_dir := get(ini_file, "details", "project_dir", string)
	export_dir := get(ini_file, "details", "export_dir", string)
	project_export_name := get(ini_file, "details", "project_export_name", string)
	build_targets := get(ini_file, "details", "build_targets", string)

	version_major := get(ini_file, "version", "version_major", u32)
	version_minor := get(ini_file, "version", "version_minor", u32)
	version_patch := get(ini_file, "version", "version_patch", u32)

	shader_in_dir := get(ini_file, "shaders", "shader_in_dir", string)
	shader_out_dir := get(ini_file, "shaders", "shader_out_dir", string)
	shader_targets := get(ini_file, "shaders", "shader_targets", string)
	shader_includes := get(ini_file, "shaders", "shader_includes", string)
	generate_dir := get(ini_file, "shaders", "generate_dir", string)


	return(
		project_dir &&
		export_dir &&
		project_export_name &&
		build_targets &&
		version_major &&
		version_minor &&
		version_patch &&
		shader_in_dir &&
		generate_dir &&
		shader_out_dir &&
		shader_targets &&
		bgfx_folder_ok &&
		shader_includes &&
		bgfx_deps_target_ok \
	)
}

//This is the worst thing that i have ever coded in my life.
init_config :: proc() {
	ini_file, ini_ok := ini.parse(CONFIG_PATH)
	defer if ini_ok do ini.destroy(ini_file)

	if !ini_ok {
		fmt.println("Error parsing project config file.")
		return
	}

	ini.add_parser(ini_file, u32, parse_u32)

	bgfx_folder, _ := ini.get(ini_file, "dev-dependencies", "bgfx_folder", string)
	bgfx_deps_target, _ := ini.get(ini_file, "dev-dependencies", "bgfx_deps_target", string)

	project_dir, _ := ini.get(ini_file, "details", "project_dir", string)
	export_dir, _ := ini.get(ini_file, "details", "export_dir", string)
	project_export_name, _ := ini.get(ini_file, "details", "project_export_name", string)
	build_targets, _ := ini.get(ini_file, "details", "build_targets", string)

	version_major, _ := ini.get(ini_file, "version", "version_major", u32)
	version_minor, _ := ini.get(ini_file, "version", "version_minor", u32)
	version_patch, _ := ini.get(ini_file, "version", "version_patch", u32)

	shader_in_dir, _ := ini.get(ini_file, "shaders", "shader_in_dir", string)
	shader_out_dir, _ := ini.get(ini_file, "shaders", "shader_out_dir", string)
	shader_targets, _ := ini.get(ini_file, "shaders", "shader_targets", string)
	shader_includes, _ := ini.get(ini_file, "shaders", "shader_includes", string)
	generate_dir, _ := ini.get(ini_file, "shaders", "generate_dir", string)


	globalConfig.bgfx_folder, _ = filepath.to_slash(strings.clone(bgfx_folder))
	globalConfig.bgfx_deps_target, _ = filepath.to_slash(strings.clone(bgfx_deps_target))

	globalConfig.project_dir, _ = filepath.to_slash(strings.clone(project_dir))
	globalConfig.export_dir, _ = filepath.to_slash(strings.clone(export_dir))
	globalConfig.project_export_name = strings.clone(project_export_name)

	globalConfig.version_major = version_major
	globalConfig.version_minor = version_minor
	globalConfig.version_patch = version_patch

	globalConfig.shader_in_dir, _ = filepath.to_slash(strings.clone(shader_in_dir))
	globalConfig.shader_out_dir, _ = filepath.to_slash(strings.clone(shader_out_dir))


	shader_targets_array := strings.split(strings.clone(shader_targets), ",")
	shader_targets_dynamic: [dynamic]string
	shader_version_dynamic: [dynamic]string

	for target in shader_targets_array {
		version, _ := ini.get(ini_file, "shader_versions", target, string)

		append(&shader_targets_dynamic, target)
		append(&shader_version_dynamic, strings.clone(version))
	}

	globalConfig.shader_targets = slice.clone(shader_targets_array[:])
	globalConfig.shader_versions = slice.clone(shader_version_dynamic[:])

	os_includes, _ := filepath.to_slash(shader_includes)
	templated_includes, _ := strings.replace_all(
		os_includes,
		"%bgfx_folder%",
		globalConfig.bgfx_folder,
	)
	globalConfig.shader_includes = slice.clone(strings.split(templated_includes, ",")[:])

	globalConfig.build_targets = slice.clone(strings.split(strings.clone(build_targets), ",")[:])
	globalConfig.generate_dir, _ = filepath.to_slash(strings.clone(generate_dir))

}

config_exists :: proc() -> bool {
	return os.file_size_from_path(CONFIG_PATH) != -1
}
