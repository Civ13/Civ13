// Yoniked from https://github.com/tgstation/rust-g/blob/f60d7745a87ae0cb2a4d00486dbed13b8b772295/src/byond.rs

/*
MIT License

Copyright (c) 2018 Bjorn Neergaard, /tg/station contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

use std::{
	borrow::Cow,
	cell::RefCell,
	ffi::{CStr, CString},
	os::raw::{c_char, c_int},
	slice,
};

static EMPTY_STRING: c_char = 0;
thread_local! {
	static RETURN_STRING: RefCell<CString> = RefCell::new(CString::default());
}

pub unsafe fn parse_args<'a>(argc: c_int, argv: *const *const c_char) -> Vec<Cow<'a, str>> {
	unsafe {
		slice::from_raw_parts(argv, argc as usize)
			.iter()
			.map(|ptr| CStr::from_ptr(*ptr))
			.map(|cstr| cstr.to_string_lossy())
			.collect()
	}
}

pub fn byond_return(value: Option<Vec<u8>>) -> *const c_char {
	match value {
		None => &EMPTY_STRING,
		Some(vec) if vec.is_empty() => &EMPTY_STRING,
		Some(vec) => RETURN_STRING.with(|cell| {
			// Panicking over an FFI boundary is bad form, so if a NUL ends up
			// in the result, just truncate.
			let cstring = match CString::new(vec) {
				Ok(s) => s,
				Err(e) => {
					let (pos, mut vec) = (e.nul_position(), e.into_vec());
					vec.truncate(pos);
					CString::new(vec).unwrap_or_default()
				}
			};
			cell.replace(cstring);
			cell.borrow().as_ptr()
		}),
	}
}

#[macro_export]
macro_rules! byond_fn {
	(fn $name:ident() $body:block) => {
		#[no_mangle]
		#[allow(clippy::missing_safety_doc)]
		pub unsafe extern "C" fn $name(
			_argc: ::std::os::raw::c_int, _argv: *const *const ::std::os::raw::c_char
		) -> *const ::std::os::raw::c_char {
			let closure = || ($body);
			$crate::byond_export::byond_return(closure().map(From::from))
		}
	};

	(fn $name:ident($($arg:ident),* $(, ...$rest:ident)?) $body:block) => {
		#[no_mangle]
		#[allow(clippy::missing_safety_doc)]
		pub unsafe extern "C" fn $name(
			_argc: ::std::os::raw::c_int, _argv: *const *const ::std::os::raw::c_char
		) -> *const ::std::os::raw::c_char {
			let __args = unsafe { $crate::byond_export::parse_args(_argc, _argv) };

			let mut __argn = 0;
			$(
				let $arg: &str = __args.get(__argn).map_or("", |cow| &*cow);
				__argn += 1;
			)*
			$(
				let $rest = __args.get(__argn..).unwrap_or(&[]);
			)?

			let closure = || ($body);
			$crate::byond_export::byond_return(closure().map(From::from))
		}
	};
}

// Easy version checker. It's in this file so it is always included
byond_fn!(
	fn get_version() {
		Some(env!("CARGO_PKG_VERSION"))
	}
);