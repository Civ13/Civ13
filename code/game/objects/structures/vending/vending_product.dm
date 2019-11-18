/**
 *  Datum used to hold information about a product in a vending machine
 */
/datum/data/vending_product
	var/product_name = "generic" // Display name for the product
	var/product_path = null
	var/amount = 0            // The original amount held in the vending machine
	var/price = 0              // Price to buy one
	var/display_color = null   // Display color for vending machine listing
	var/vending_machine        // The vending machine we belong to
	var/image/product_image			//an image to be used as an overlay in the vending machine

/datum/data/vending_product/New(var/_vending_machine, var/path, var/name = null, var/_amount = 1, var/_price = 0, var/_color = null, var/_icon = null, var/_icon_state = null, var/_color = null)
	..()

	product_path = path

	if (!name)
		var/atom/tmp = path
		product_name = initial(tmp.name)
	else
		product_name = name

	amount = _amount
	price = _price
	display_color = _color
	vending_machine = _vending_machine
	if (_icon && _icon_state)
		product_image = image(icon=_icon, icon_state = _icon_state)
		product_image.color = _color
	else
		var/obj/item/NI = new product_path
		product_image = image(icon=NI.icon, icon_state = NI.icon_state)
		product_image.color = NI.color
		qdel(NI)

/datum/data/vending_product/Destroy()
	vending_machine = null
	. = ..()

/datum/data/vending_product/proc/add_product(var/atom/movable/product)
	if (product.type != product_path)
		return FALSE
	amount++
/datum/data/vending_product/proc/get_product(var/product_location, var/p_amount=1)
	if (amount < p_amount || !product_location)
		return
	if (findtext("[product_path]","obj/item/stack"))
		var/obj/item/stack/product = new product_path
		if (product)
			product.amount = p_amount
			product.forceMove(product_location)
			amount -= p_amount
	else
		for(var/i=1, i<=p_amount, i++)
			var/atom/movable/product = new product_path
			if (product)
				product.forceMove(product_location)
				amount--
	return TRUE