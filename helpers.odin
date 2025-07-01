package runebuild

import "core:mem"
import "core:strconv"
import "core:strings"

import "shared:ini"

int_to_string :: proc(i: int) -> string {
	buf: [64]u8 = ---

	result := strconv.itoa(buf[:], i)

	return strings.clone(result)
}


int_to_bool :: proc(n: int) -> bool {
	return n != 0
}

parse_u32 :: proc(ini_file: ^ini.Ini_File, val: string, data: any) -> bool {
	v, _ := strconv.parse_u64(val)
	tmp := u32(v)
	mem.copy(data.data, &tmp, size_of(u32))

	return true
}
