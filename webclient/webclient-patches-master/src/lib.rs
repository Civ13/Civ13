#![forbid(unsafe_op_in_unsafe_fn)]

use std::ffi::{c_char, CStr};
use std::{collections::hash_map::HashMap};
use std::cell::RefCell;

use byond_export::byond_return;
use detour::RawDetour;
use skidscan::{Signature, signature};

// I have literally never touched rust before so don't yell at me too hard please
// I only used rust because otherwise people would yell at me like "ree why didn't you use rust"
// also the compiling tools are less ass, because otherwise this is literally fitting a
// square peg (low level ass hacky shit) into a round hole (rust)

#[macro_use]
mod byond_export;

thread_local! {
	static TOKEN_MAP: RefCell<HashMap<String, String>> = RefCell::new(HashMap::new());
	static CLIENT_MAP: RefCell<HashMap<u16, (String, String)>> = RefCell::new(HashMap::new());
}
static mut LOADED : bool = false;

byond_fn!(
	fn set_webclient_auth(token, info) {
		if let Err(e) = init_module() {
			return Some(e);
		}
		TOKEN_MAP.with(|cell| {
			let mut map = cell.borrow_mut();
			map.insert(String::from(token), String::from(info));
		});
		Some("")
	}
);

fn get_client_info(token: String, client_id: u16) -> Result<String, ()> {
	CLIENT_MAP.with(|cell| {
		let mut cmap = cell.borrow_mut();
		if let Some((cert, info)) = cmap.get(&client_id) {
			if *cert == token  {
				return Ok(info.clone());
			}
			cmap.remove(&client_id);
		}
		TOKEN_MAP.with(|cell| {
			let mut map = cell.borrow_mut();
			match map.remove(&token) {
				Some(info) => {
					cmap.insert(client_id, (token, info.clone()));
					Ok(info)
				},
				None => Err(())
			}
		})
	})
}

byond_fn!(
	fn remove_webclient_patches() {
		unsafe {
			if !LOADED {return Some("");}
			LOADED = false;
		}
		undo_replacements();
		Some("")
	}
);

struct SigOffset(Signature, u32);

static mut ORIG_REPLACEMENTS : Vec<(*mut u32, u32)> = vec![];
static mut ORIG_BYTE_REPLACEMENTS : Vec<(*mut u8, Vec<u8>)> = vec![];
static mut DETOURS : Vec<RawDetour> = vec![];

unsafe fn extract_function_call(sig : SigOffset, module : &str) -> Result<u32, ()> {
	unsafe {
		if let Ok(ptr) = sig.0.scan_module(module) {
			Ok(*(((ptr as u32) + sig.1) as *mut u32) + (ptr as u32 + sig.1) + 4)
		} else {
			Err(())
		}
	}
}
unsafe fn replace_bytes(target : *mut u8, bytes : &[u8]) -> Result<(), ()> {
	unsafe {
		if let Err(_) = region::protect(target, bytes.len(), region::Protection::READ_WRITE_EXECUTE) {
			return Err(());
		}
		let slice = std::slice::from_raw_parts_mut(target, bytes.len());
		ORIG_BYTE_REPLACEMENTS.push((target, slice.to_vec()));
		slice.copy_from_slice(bytes);
	}
	Ok(())
}
unsafe fn replace_function_call(sig : SigOffset, module : &str, replacement_ptr : u32) -> Result<(), ()> {
	unsafe {
		if let Ok(ptr) = sig.0.scan_module(module) {
			let call_ptr = (ptr as u32 + sig.1) as *mut u32;
			if let Err(_) = region::protect(call_ptr, 4, region::Protection::READ_WRITE_EXECUTE) {
				return Err(());
			}
			ORIG_REPLACEMENTS.push((call_ptr, *call_ptr));
			*call_ptr = replacement_ptr - (call_ptr as u32) - 4;
			Ok(())
		} else {
			Err(())
		}
	}
}
fn undo_replacements() {
	unsafe {
		ORIG_REPLACEMENTS.reverse();
		for (ptr, orig) in ORIG_REPLACEMENTS.iter() {
			**ptr = *orig;
		}
		ORIG_REPLACEMENTS.clear();
		ORIG_BYTE_REPLACEMENTS.reverse();
		for (ptr, orig) in ORIG_BYTE_REPLACEMENTS.iter() {
			let slice = std::slice::from_raw_parts_mut(*ptr, orig.len());
			slice.copy_from_slice(orig);
		}
		ORIG_BYTE_REPLACEMENTS.clear();
		DETOURS.reverse();
		for detour in DETOURS.iter() {
			let _ = detour.disable();
		}
		DETOURS.clear();
	}
}

#[cfg(windows)]
const BYONDCORE: &str = "byondcore.dll";
#[cfg(unix)]
const BYONDCORE: &str = "libbyond.so";

fn init_module() -> Result<(), &'static str> {
	unsafe {
		if LOADED { return Ok(()); }
		LOADED = true;

		#[cfg(windows)]
		let sig_short = SigOffset(
			signature!("8d 45 e0 8b cf 50 53 e8 ?? ?? ?? ?? b8 ff bf 00 00"),
			8
		);
		#[cfg(windows)]
		let sig_write_flags_delete = SigOffset(
			signature!("a9 00 80 00 00 75 ?? ff 45 ?? 8b cf 53 6a 00 e8 ?? ?? ?? ?? 0f b6 4e"),
			16
		);
		#[cfg(windows)]
		let sig_write_flags_modify = SigOffset(
			signature!("53 89 45 e0 e8 ?? ?? ?? ?? 8b 4e 24 0f b6 46 20 81 e1 ff ff ff 00"),
			5
		);
		// Instructions on finding this in Ghidra (works on linux too):
		// Literally just search for the string "web:". You'll have to use the search feature (press S)
		// and change the type to string. The function that contains that will be the function you want.
		#[cfg(windows)]
		let sig_check_webclient_cert = signature!(
			"55 8b ec 6a ff 68 ?? ?? ?? ?? 64 a1 00 00 00 00 50 83 ec 08 53 56 57 a1 ?? ?? ?? ?? 33 c5 50 8d 45 f4 64 a3 00 00 00 00 89 4d f0 68 68 04 00 00 e8 ?? ?? ?? ?? 83 c4 04 89 45 ec c7 45 fc 00 00 00 00 85 c0 74 18 6a 00 ff 75 28 8b c8 ff 75 24 68 e6 00 00 00"
		);// 55 8B EC 6A FF 68 3B 89 88 63 64 A1 00 00 00 00 50 83 EC 08 53 56 57 A1 58 12 8F 63 33 C5 50 8D 45 F4 64 A3 00 00 00 00 89 4D F0 68 68 04 00 00 E8 C5 05 0A 00 83 C4 04 89 45 EC C7 45 FC 00 00 00 00 85 C0 74 18 6A 00 FF 75 28 8B C8 FF 75 24 68 E6 00 00 00 E8 96 6F FF FF 8B F8 EB 02 33 FF 8B 75 0C 32 DB 68 78 60 8A 63 56 C7 45 FC FF FF FF FF FF 15 38 D4 88 63 83 C4 08 0F B6 DB 85 C0 B9 01 00 00 00 8D 47 04 0F 45 D9 8B CF 50 88 5D 28 FF 75 28 E8 C7 51 00 00 8D 47 04 8B CF 50 FF 75 08 E8 29 56 00 00 8D 47 04 8B CF 50 56 E8 1D 56 00 00 80 FB 01 75 5C 8D 77 04 8B CF 56 FF 75 10 E8 0A 56 00 00 8B 5D 14 8B CF 56 53 E8 8E 51 00 00 84 DB 75 44 56 FF 75 18 8B CF E8 EF 55 00 
		#[cfg(unix)]
		let sig_short = SigOffset(
			signature!("89 54 24 08 89 44 24 04 89 34 24 e8 ?? ?? ?? ?? 66 81 63 38 ff bf 8b 5d c4 85 db"),
			12
		);
		#[cfg(unix)]
		let sig_write_flags_delete = SigOffset(
			signature!("89 34 24 e8 ?? ?? ?? ?? 89 7c 24 08 0f b6 43 20 8b 53 24 89 34 24 c1 e0 18 81 e2 ff ff ff 00"),
			4
		);
		#[cfg(unix)]
		let sig_write_flags_modify = SigOffset(
			signature!("8b 56 04 89 44 24 04 89 7c 24 08 89 34 24 89 55 e0 e8 ?? ?? ?? ?? 89 7c 24 08 0f b6 43 20 8b 53 24 89 34 24"),
			18
		);
		#[cfg(unix)]
		let sig_check_webclient_cert = signature!(
			"55 89 e5 57 56 53 83 ec 4c 8b 45 08 8b 55 0c 8b 75 10 0f b6 7d 18 89 45 e0 8b 45 14 89 55 d8 8b 55 1c c7 04 24 5c 04 00 00"
		);

		// This part patches BYOND's code which encodes modified movables into network messages for the webclient.
		// The way the code works is that it writes a byte into the message, holding onto a pointer to that byte.
		// Later, after writing the various changes, this flag byte is updated. Unfortunately this is a short and not
		// a byte like before, so this clobbers the least significant byte of the movable's ID. What this changes is that
		// the flags is now reserved 2 bytes, to fit the expanded flags to include the vis_contents flag.
		// This will unfortunately break the official webclient even more than it's already broken.

		// This is clearly a case of "Lummox started working on it and then didn't bother to finish"
		
		if let Ok(short_ptr) = extract_function_call(sig_short, BYONDCORE) {

			if let Err(_) = replace_function_call(sig_write_flags_delete, BYONDCORE, short_ptr) {
				return Err("Couldn't find delete-atom flags write call");
			}
			if let Err(_) = replace_function_call(sig_write_flags_modify, BYONDCORE, short_ptr) {
				return Err("Couldn't find modify-atom flags write call");
			}// 00 e9

		} else {
			return Err("Couldn't find short-write ptr!");
		}

		// This part hooks the login code so that we can actually login!
		// This is necessary because the default BYOND webclient loginy thing is full of problems like:
		// - Being completely fucked over by Cloudflare
		// - Being completely incompatible with HTTPS
		//   - Basically, BYOND's webclient iframe thingy will break horribly if you give it an https thingy
		//   - It's worse than that: BYOND's iframe thingy will also break if you give it an http thingy
		//     - That's cause browsers don't like it when you mix http and https
		//   - Even if I could get that to work, yogstation has HSTS so that's a no go
		// - Requiring you to put your thing inside of BYOND's iframe bullshit
		//   - This solution might make lummox mad at me because it bypasses ads.

		if let Ok(check_webclient_cert) = sig_check_webclient_cert.scan_module(BYONDCORE) {
			let hook = RawDetour::new(check_webclient_cert as *const (), webclient_certificate_hook_platform as *const ())
				.map_err(|_| "Couldn't detour check_webclient_cert")?;
			hook.enable()
				.map_err(|_| "Couldn't enable detour for check_webclient_cert")?;
			DETOURS.push(hook);
		} else {
			return Err("Couldn't find check_webclient_cert")
		}

		// Fixes the wrong object ID being sent when sending contents of turfs within vis_contents
		// Did I say this looks like a case of code that never was really finished? Oh yeah.
		// 
		// The frame loop part disables server-side .dmi parsing. Nothing wrong with it, it works perfectly fine
		// as long as you have less than 65535 unique frames. If you reach that the server crashes. So let's not.
		#[cfg(windows)] {
			// unfortunately the actual object ID is put in EAX and then thrown away so there's a lot
			// of twiddling around I had to do to stick it onto the stack and then take it off of the
			// stack at the correct spot. Basically popping the value after the function call, pushing it
			// before the next call, popping it again, and then pushing it as the argument to the function
			// call it actually needs to go to

			if let Ok(obj_ptr) = signature!(
				"8b 4d e8 8b 41 08 3d ff ff 00 00 74 52 90 50 e8 ?? ?? ?? ?? 8b f8 83 c4 04 85 ff 74 42 53 ff 77 04 ff 37 e8 ?? ?? ?? ?? 8b 4d ec 83 c4 0c 0f b6 c0 50 57 53 ff 75 f0 e8 ?? ?? ?? ??"
			).scan_module(BYONDCORE) {
				if let Err(_) = replace_bytes(obj_ptr.offset(22), &[0x5a, 0x90, 0x85, 0xff, 0x74, 0x43, 0x52])
				.and_then(|_| replace_bytes(obj_ptr.offset(49), &[0x5a, 0x50, 0x57, 0x52, 0x6a, 0x02])) {
					return Err("Couldn't patch obj in turf in vis contents code");
				}
			} else {
				return Err("Couldn't find obj in turf in vis contents sending code");
			}
			
			if let Ok(mob_ptr) = signature!(
				"8b 45 e8 8b 40 0c 3d ff ff 00 00 74 53 8b ff 50 e8 ?? ?? ?? ?? 8b f8 83 c4 04 85 ff 74 42 53 ff 77 04 ff 37 e8 ?? ?? ?? ?? 8b 4d ec 83 c4 0c 0f b6 c0 50 57 53 ff 75 f0 e8 ?? ?? ?? ??"
			).scan_module(BYONDCORE) {
				if let Err(_) = replace_bytes(mob_ptr.offset(23), &[0x5a, 0x90, 0x85, 0xff, 0x74, 0x43, 0x52])
				.and_then(|_| replace_bytes(mob_ptr.offset(50), &[0x5a, 0x50, 0x57, 0x52, 0x6a, 0x03])) {
					return Err("Couldn't patch mob in turf in vis contents code");
				}
			} else {
				return Err("Couldn't find mob in turf in vis contents sending code");
			}

			if let Ok(frame_loop_ptr) = signature!(
				"0f 8e ba 00 00 00 eb 06 8d 9b 00 00 00 00"
			).scan_module(BYONDCORE) {
				if let Err(_) = replace_bytes(frame_loop_ptr, &[0x90, 0xe9]) {
					return Err("Couldn't patch dmi frame loop code");
				}
			} else {
				return Err("Couldn't find dmi frame loop code");
			}
		}
		#[cfg(unix)] {
			// I love GCC but the code it generates is too optimized and that makes this shit really fucking hard
			// I ended up removing the checks for `id == 0xFFFF` to make room for this because those checks are redundant... I hope.
			// the linux version also throws away the ID on me so yeah
			let id_saver_bytes = [0x89u8, 0x44, 0x24, 0x10, 0x90, 0x90, 0x90];
			let obj_patch = [0x8Bu8, 0x4C, 0x24, 0x10, 0x89, 0x14, 0x24, 0x89, 0x44, 0x24, 0x10, 0x89, 0x4C, 0x24, 0x08, 0xC6, 0x44, 0x24, 0x04, 0x02, 0x90];
			let mob_patch = [0x8Bu8, 0x4C, 0x24, 0x10, 0x89, 0x14, 0x24, 0x89, 0x44, 0x24, 0x10, 0x89, 0x4C, 0x24, 0x08, 0xC6, 0x44, 0x24, 0x04, 0x03, 0x90];

			if let Ok(obj_ptr) = signature!(
				"3d ff ff 00 00 74 7e 89 7d d0 89 f7 0f b7 75 e2 89 5d c8 eb 53 89 7c 24 08 8b 53 04 8b 00 89 54 24 04 89 04 24 e8 ?? ?? ?? ?? 8b 55 dc 89 5c 24 0c 89 7c 24 08 89 14 24 0f b6 c0 89 44 24 10 8b 45 d0 89 44 24 04 e8 ?? ?? ?? ?? 8b 53 50 09 c6 85 d2 74 0a 8b 45 d4 e8 ?? ?? ?? ?? 09 c6 8b 43 48 3d ff ff 00 00 74 0e"
			).scan_module(BYONDCORE) {
				if let Err(_) = replace_bytes(obj_ptr.offset(0), &id_saver_bytes)
				.and_then(|_| replace_bytes(obj_ptr.offset(0x61), &id_saver_bytes))
				.and_then(|_| replace_bytes(obj_ptr.offset(0x31), &obj_patch)) {
					return Err("Couldn't patch obj in turf in vis contents code");
				}
			} else {
				return Err("Couldn't find obj in turf in vis contents sending code");
			}

			if let Ok(mob_ptr) = signature!(
				"3d ff ff 00 00 74 76 89 7d d0 89 f7 0f b7 75 e2 89 5d c8 eb 53 89 7c 24 08 8b 53 04 8b 00 89 54 24 04 89 04 24 e8 ?? ?? ?? ?? 8b 55 dc 89 5c 24 0c 89 7c 24 08 89 14 24 0f b6 c0 89 44 24 10 8b 45 d0 89 44 24 04 e8 ?? ?? ?? ?? 8b 53 50 09 c6 85 d2 74 0a 8b 45 d4 e8 ?? ?? ?? ?? 09 c6 8b 43 48 3d ff ff 00 00 74 0e"
			).scan_module(BYONDCORE) {
				if let Err(_) = replace_bytes(mob_ptr.offset(0), &id_saver_bytes)
				.and_then(|_| replace_bytes(mob_ptr.offset(0x61), &id_saver_bytes))
				.and_then(|_| replace_bytes(mob_ptr.offset(0x31), &mob_patch)) {
					return Err("Couldn't patch mob in turf in vis contents code");
				}
			} else {
				return Err("Couldn't find mob in turf in vis contents sending code");
			}

			if let Ok(frame_loop_ptr) = signature!(
				"0f 8e b4 01 00 00 31 f6 8d bd 1c ff ff ff eb 62 66 90"
			).scan_module(BYONDCORE) {
				if let Err(_) = replace_bytes(frame_loop_ptr, &[0x90, 0xe9]) {
					return Err("Couldn't patch dmi frame loop code");
				}
			} else {
				return Err("Couldn't find dmi frame loop code");
			}
		}
		
		Ok(())
	}
}

unsafe fn webclient_certificate_hook(token:*const c_char,callback : extern "C" fn(bool, *const c_char, u16)->(), client_id:u16) {
	match get_client_info(unsafe {CStr::from_ptr(token)}.to_string_lossy().into_owned(), client_id) {
		Ok(cert) => callback(true, byond_return(Some(cert.into_bytes())), client_id),
		_ => callback(false, byond_return(Some("Auth failed".as_bytes().to_vec())), client_id)
	};
}

// This thing gets called more than once for each player.
// The first time is on login.
// Later on, it's called with a different callback that just boots the player out
// with an undescriptive error message periodically. A previous implementation I did hooked
// a different function, and it only handled the first time, which meant players could
// log in but everyone on the server would just get booted out randomly for no reason
// periodically.
// Funny enough fixing this actually made this whole library simpler and eliminated the need to include a smidge of c code. So yay?

#[cfg(windows)]
extern "fastcall" fn webclient_certificate_hook_platform(_this:u32, _eax:u32, _:u32, token:*const c_char, _:u32, _:u32, _:u32, _:u32, _:u32, callback : extern "C" fn(bool, *const c_char, u16)->(), client_id:u16)->() {
	unsafe {webclient_certificate_hook(token, callback, client_id);}
}
#[cfg(unix)]
extern "C" fn webclient_certificate_hook_platform(_this:u32, _:u32, token:*const c_char, _:u32, _:u32, _:u32, _:u32, _:u32, callback : extern "C" fn(bool, *const c_char, u16)->(), client_id:u16)->() {
	unsafe {webclient_certificate_hook(token, callback, client_id);}
}

// So there, is this shitty little DLL really *that much better* just because I wrote it in rust?

// is it?

#[cfg(not(target_pointer_width = "32"))]
compile_error!("webclient-patches must be compiled for a 32-bit target");
