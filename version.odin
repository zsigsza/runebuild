package runebuild
import "core:fmt"

version_command :: proc(args: []string) {
	fmt.printfln("{0} {1}", PROGRAM_NAME, PROGRAM_VERSION)
}
