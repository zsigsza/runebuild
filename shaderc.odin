package runebuild

import "base:runtime"
import "core:fmt"
import "core:os/os2"
import "core:path/filepath"
import "core:path/slashpath"
import "core:slice"
import "core:strings"
import "shared:ini"

ShaderPlatform :: enum {
	Android,
	AsmJs,
	Ios,
	Linux,
	Orbis,
	Osx,
	Windows,
}

shader_platform_to_string :: proc(platform: ShaderPlatform) -> string {
	switch platform {
	case .Android:
		return "android"
	case .AsmJs:
		return "asm.js"
	case .Ios:
		return "ios"
	case .Linux:
		return "linux"
	case .Orbis:
		return "orbis"
	case .Osx:
		return "osx"
	case .Windows:
		return "windows"
	}

	panic("This should not happen :(")
}

ShaderType :: enum {
	Vertex,
	Fragment,
	Compute,
}

shader_type_to_string :: proc(type: ShaderType) -> string {
	switch type {
	case .Vertex:
		return "vertex"
	case .Fragment:
		return "fragment"
	case .Compute:
		return "compute"
	}

	panic("This should not happen :(")
}


ShaderCompilationInfo :: struct {
	in_file:          string,
	out_file:         string,
	varying_def_file: string,
	includes:         []string,
	type:             ShaderType,
	platform:         ShaderPlatform,
	profile:          string,
}

get_shader_c_path :: proc(is_debug: bool) -> string {
	when ODIN_OS == .Windows {
		program_name := strings.join({"shaderc", is_debug ? "Debug" : "Release", ".exe"}, "")
	} else {
		program_name := strings.join({"shaderc", is_debug ? "Debug" : "Release"}, "")
	}

	return slashpath.join(
		{globalConfig.bgfx_folder, ".build", globalConfig.bgfx_deps_target, "bin", program_name},
	)
}

use_shader_c :: proc(info: ShaderCompilationInfo, is_debug: bool) {
	path := get_shader_c_path(is_debug)


	shader_type := strings.join({"--type", shader_type_to_string(info.type)}, " ")
	shader_platform := strings.join({"--platform", shader_platform_to_string(info.platform)}, " ")
	shader_profile := strings.join({"--profile", info.profile}, " ")
	varying_def_file := strings.join({"--varyingdef", info.varying_def_file}, " ")


	final_command: [dynamic]string
	append(
		&final_command,
		path,
		"-f",
		info.in_file,
		"-o",
		info.out_file,
		"--type",
		shader_type_to_string(info.type),
		"--platform",
		shader_platform_to_string(info.platform),
		"--profile",
		info.profile,
		"--varyingdef",
		info.varying_def_file,
	)

	for include in info.includes {
		append(&final_command, "-i")
		append(&final_command, include)
	}

	desc := os2.Process_Desc {
		command = final_command[:],
	}

	state, stdout, stderr, _ := os2.process_exec(desc, context.allocator)


	if len(stdout) > 0 {
		fmt.printfln(
			"Error while compiling \"{0}\" {1} shader for {2} ({3})",
			info.in_file,
			shader_type_to_string(info.type),
			shader_platform_to_string(info.platform),
			info.profile,
		)
		fmt.println(strings.clone_from_bytes(stdout))
		fmt.println("--------------------------------------------------")
	}

}


compile_shaders :: proc(is_debug: bool, ini_file: ^ini.Ini_File) {
	os2.remove_all(globalConfig.shader_out_dir)
	os2.make_directory_all(globalConfig.shader_out_dir)
	paths, var_names, shader_names, shader_count := _compile_shaders(
		globalConfig.shader_in_dir,
		is_debug,
		ini_file,
	)

	offset, build_order := get_shader_normal_offsets(ini_file)
	generate_shader_definitions(var_names, paths, offset, shader_count, build_order, shader_names)
}

_compile_shaders :: proc(
	path: string,
	is_debug: bool,
	ini_file: ^ini.Ini_File,
) -> (
	[][]string,
	[][]string,
	[]string,
	int,
) {
	infos, err := os2.read_all_directory_by_path(path, context.temp_allocator)

	paths: [dynamic][]string
	var_names: [dynamic][]string
	shader_count: int
	shader_names: [dynamic]string

	is_shader := false
	for info in infos {
		if info.name != "varying.def.sc" do continue
		is_shader = true
		break
	}


	if !is_shader {
		for info in infos {
			if info.type != .Directory do continue

			_paths, _var_names, _shader_names, count := _compile_shaders(
				slashpath.join({path, info.name}),
				is_debug,
				ini_file,
			)

			shader_count += count
			append(&paths, .._paths[:])
			append(&var_names, .._var_names[:])
			append(&shader_names, .._shader_names[:])
		}
	} else {
		shader_count += 1
		append(&shader_names, filepath.base(path))
		is_compute := false
		for info in infos {
			if strings.split("_", info.name)[0] != "cs" do continue
			is_compute = true
			break
		}

		varying_def := slashpath.join({path, "varying.def.sc"})


		for build_target in globalConfig.build_targets {

			_var_names: [dynamic]string
			_paths: [dynamic]string
			shader_blacklist: []string

			val, ok := ini.get(
				ini_file,
				strings.join({"build-rule-", build_target}, ""),
				"dont_build_shaders",
				string,
			)

			if ok {
				shader_blacklist = strings.split(val, ",")
			}

			build_folder_path := slashpath.join({globalConfig.shader_out_dir, build_target})
			os2.make_directory(build_folder_path)


			for shader_target, i in globalConfig.shader_targets {
				if slice.contains(shader_blacklist, shader_target) {
					continue
				}

				shader_target_folder := slashpath.join({build_folder_path, shader_target})
				os2.make_directory(shader_target_folder)

				if (is_compute) {
					//TODO:

				} else {
					fragment_shader_name := get_shader_name_from_files(.Fragment, infos)
					vertex_shader_name := get_shader_name_from_files(.Vertex, infos)

					fragment_shader_name_without_extension :=
						strings.split(fragment_shader_name, ".")[0]

					vertex_shader_name_without_extension :=
						strings.split(vertex_shader_name, ".")[0]


					vertex_path_without_shader_root: [dynamic]string
					append(&vertex_path_without_shader_root, shader_target_folder)
					append(&vertex_path_without_shader_root, ..strings.split(path, "/")[1:])

					os2.make_directory_all(slashpath.join(vertex_path_without_shader_root[:]))

					append(
						&vertex_path_without_shader_root,
						strings.join({vertex_shader_name_without_extension, ".bin"}, ""),
					)

					vertex_out := slashpath.join(vertex_path_without_shader_root[:])
					relative_vertex_bin_path, _ := filepath.rel(
						globalConfig.generate_dir,
						vertex_out,
					)
					slashed_vertex_bin_path, _ := filepath.to_slash(relative_vertex_bin_path)
					append(&_paths, slashed_vertex_bin_path)
					append(
						&_var_names,
						strings.join(
							{filepath.base(path), "vertex", shader_target, build_target},
							"_",
						),
					)
					process_shader(
						slashpath.join({path, vertex_shader_name}),
						vertex_out,
						varying_def,
						i,
						build_target,
						is_debug,
						.Vertex,
					)

					fragment_path_without_shader_root: [dynamic]string
					append(&fragment_path_without_shader_root, shader_target_folder)
					append(&fragment_path_without_shader_root, ..strings.split(path, "/")[1:])
					append(
						&fragment_path_without_shader_root,
						strings.join({fragment_shader_name_without_extension, ".bin"}, ""),
					)

					fragment_out := slashpath.join(fragment_path_without_shader_root[:])
					relative_fragment_bin_path, _ := filepath.rel(
						globalConfig.generate_dir,
						fragment_out,
					)
					slashed_fragment_bin_path, _ := filepath.to_slash(relative_fragment_bin_path)
					append(&_paths, slashed_fragment_bin_path)
					append(
						&_var_names,
						strings.join(
							{filepath.base(path), "fragment", shader_target, build_target},
							"_",
						),
					)
					process_shader(
						slashpath.join({path, fragment_shader_name}),
						fragment_out,
						varying_def,
						i,
						build_target,
						is_debug,
						.Fragment,
					)
				}
			}
			append(&var_names, _var_names[:])
			append(&paths, _paths[:])
		}

	}
	return paths[:], var_names[:], shader_names[:], shader_count
}

process_shader :: proc(
	in_file: string,
	out_file: string,
	varying_def: string,
	profile_index: int,
	build_target: string,
	is_debug: bool,
	type: ShaderType,
) {
	use_shader_c(
		ShaderCompilationInfo {
			in_file = in_file,
			out_file = out_file,
			includes = globalConfig.shader_includes,
			platform = get_platform_from_build_target(build_target),
			profile = globalConfig.shader_versions[profile_index],
			varying_def_file = varying_def,
			type = type,
		},
		is_debug,
	)
}

get_platform_from_build_target :: proc(target: string) -> ShaderPlatform {
	if strings.contains(target, "windows") {
		return .Windows
	}

	if strings.contains(target, "linux") {
		return .Linux
	}

	if strings.contains(target, "darwin") {
		return .Osx
	}

	panic("Unsupported build_target")
}

get_shader_name_from_files :: proc(type: ShaderType, files: []os2.File_Info) -> string {
	switch type {
	case .Fragment:
		for file in files {
			if strings.split(file.name, "_")[0] != "fs" do continue
			return file.name
		}
	case .Vertex:
		for file in files {
			if strings.split(file.name, "_")[0] != "vs" do continue
			return file.name
		}
	case .Compute:
		for file in files {
			if strings.split(file.name, "_")[0] != "cs" do continue
			return file.name
		}
	}
	panic("No shader has been found.")
}

generate_shader_definitions :: proc(
	normal_shaders_var_names: [][]string,
	normal_shaders_paths: [][]string,
	normal_shader_offset: []int,
	shader_count: int,
	build_order: [][]string,
	shader_names: []string,
) {
	file_content: [dynamic]string
	append(&file_content, "package generated")
	append(&file_content, "import \"shared:bgfx\"")
	append(&file_content, "NormalShader :: enum {")
	for shader_name, i in shader_names {
		append(&file_content, strings.join({"\t", strings.to_ada_case(shader_name), ","}, ""))
	}
	append(&file_content, "}")
	for build_target, i in globalConfig.build_targets {
		os_enum: string

		if strings.contains(build_target, "windows") {
			os_enum = ".Windows"
		} else if strings.contains(build_target, "linux") {
			os_enum = ".Linux"
		} else if strings.contains(build_target, "darwin") {
			os_enum = ".Darwin"
		} else {
			panic("Unsupported build target.")
		}

		append(&file_content, strings.join({"when ODIN_OS ==", os_enum, "{"}, " "))

		append(
			&file_content,
			strings.join({"\tOFFSET ::", int_to_string(int(normal_shader_offset[i]))}, " "),
		)

		append(
			&file_content,
			strings.join(
				{"\tBUILD_ORDER: []string : ", "{", strings.join(build_order[i], ", "), "}"},
				"",
			),
		)

		shader_var_names: [dynamic]string
		for j := i;
		    j < len(globalConfig.build_targets) * shader_count;
		    j += len(globalConfig.build_targets) {
			shader_path_array := normal_shaders_paths[j]
			shader_var_name_array := normal_shaders_var_names[j]

			for k in 0 ..< normal_shader_offset[i] {
				shader_path := shader_path_array[k]
				shader_var_name := shader_var_name_array[k]
				append(&shader_var_names, shader_var_name)

				append(&file_content, "\t@(private)")
				append(&file_content, strings.join({"\t", shader_var_name, " := #load("}, ""))
				append(&file_content, strings.join({"\t\t", "\"", shader_path, "\","}, ""))
				append(&file_content, "\t)")
			}
		}

		append(&file_content, "\tshaders: [][]byte = {")
		for shader_var_name in shader_var_names {
			append(&file_content, strings.join({"\t\t", shader_var_name, ","}, ""))
		}
		append(&file_content, "\t}")

		append(&file_content, "\tget_shaders :: proc(shader: NormalShader) -> [][]byte {")
		append(&file_content, "\t\tstart := (int(shader) * (OFFSET - 1))")
		append(&file_content, "\t\tend := (start + OFFSET)")
		append(&file_content, "\t\texcluded_shaders := shaders[start:end]")
		append(&file_content, "\t\treturn excluded_shaders")
		append(&file_content, "\t}")

		append(
			&file_content,
			"\tget_shader :: proc(shader: NormalShader, type: bgfx.Renderer_Type) -> ([]byte, []byte) {",
		)
		append(&file_content, "\t\texcluded_shaders := get_shaders(shader)")
		append(&file_content, "\t\tindex := get_index(type) * 2")
		append(&file_content, "\t\tvs_shader := excluded_shaders[index]")
		append(&file_content, "\t\tfs_shader := excluded_shaders[index + 1]")
		append(&file_content, "\t\treturn vs_shader, fs_shader")
		append(&file_content, "\t}")

		append(&file_content, "\t@(private)")
		append(&file_content, "\tget_index :: proc(type: bgfx.Renderer_Type) -> int {")
		append(&file_content, "\t\trenderer_map: []string = {")
		append(&file_content, "\t\t\t\"\",")
		append(&file_content, "\t\t\t\"\",")
		append(&file_content, "\t\t\t\"hlsl\",")
		append(&file_content, "\t\t\t\"hlsl\",")
		append(&file_content, "\t\t\t\"\",")
		append(&file_content, "\t\t\t\"metal\",")
		append(&file_content, "\t\t\t\"\",")
		append(&file_content, "\t\t\t\"essl\",")
		append(&file_content, "\t\t\t\"glsl\",")
		append(&file_content, "\t\t\t\"spirv\",")
		append(&file_content, "\t\t\t\"\",")
		append(&file_content, "\t\t}")
		append(&file_content, "\t\tbackend := renderer_map[int(type)]")
		append(&file_content, "\t\tif backend == \"\" {")
		append(&file_content, "\t\t\tpanic(\"Unknown or unsupported renderer type\")")
		append(&file_content, "\t\t}")
		append(&file_content, "\t\tfor build, i in BUILD_ORDER {")
		append(&file_content, "\t\t\tif build == backend {")
		append(&file_content, "\t\t\t\treturn i")
		append(&file_content, "\t\t\t}")
		append(&file_content, "\t\t}")
		append(&file_content, "\t\tpanic(\"Unknown or unsupported renderer type\")")

		append(&file_content, "\t}")
		append(&file_content, "}")
	}

	file_content_bytes := transmute([]u8)strings.join(file_content[:], "\n")
	os2.make_directory_all(globalConfig.generate_dir)
	err := os2.write_entire_file(
		filepath.join({globalConfig.generate_dir, "shaders.odin"}),
		file_content_bytes,
	)

	if err != nil {
		fmt.println(err)
		panic("Error creating shader definitions")
	}
}

get_shader_normal_offsets :: proc(ini_file: ^ini.Ini_File) -> ([]int, [][]string) {
	offsets: [dynamic]int
	build_order: [dynamic][]string

	for build_target in globalConfig.build_targets {
		_build_order: [dynamic]string
		blacklist, ok := ini.get(
			ini_file,
			strings.join({"build-rule-", build_target}, ""),
			"dont_build_shaders",
			string,
		)

		blacklist_array: []string
		if ok {
			blacklist_array = strings.split(blacklist, ",")
		}
		blacklist_count := len(blacklist_array)

		for shader_target in globalConfig.shader_targets {
			if slice.contains(blacklist_array, shader_target) do continue
			append(&_build_order, strings.join({"\"", shader_target, "\""}, ""))
		}


		offset := (len(globalConfig.shader_targets) - blacklist_count) * 2
		append(&offsets, offset)
		append(&build_order, _build_order[:])
	}
	return offsets[:], build_order[:]
}
