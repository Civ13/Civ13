#define WWinput_first_choice(list) ((list && islist(list) && list:len) ? list[1] : null)
#define WWinput_list_or_null(_list) (_list | list("Cancel"))
