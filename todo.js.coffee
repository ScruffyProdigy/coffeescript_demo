explode_away = (obj) ->
	obj.stop()
	obj.effect 
		effect: "explode"
		pieces: 100
		complete: ->
			obj.show().css("opacity",0).slideUp
				duration: 500
				complete: ->
					obj.remove()
	
slowly_hide = (obj) ->
	obj.css("opacity",0).stop().slideUp 500, ->
		obj.detach()

slip_away = (obj) ->
	obj.stop().slideUp 600, ->
		list.remove()

slip_in = (obj,time) ->
	obj.stop().hide().slideDown(time)

fade_out = (obj) ->
	obj.stop().animate {opacity:0},
		complete: ->
			obj.slideUp
				complete: ->
					obj.remove()

wiggle = (obj) -> obj.stop().animate({"width":250},200).animate({"width":165},200).animate({"width":200},200)

active_category= () ->	$(".active").attr("id")
find_todo= (id) -> $(".todo[todo_id="+id+"]")
get_date_list = (date) -> $("#"+date)

get_todo_date = (todo) -> todo.attr("date")
is_input_empty= (input) -> input.val() == ""
will_list_be_empty = (list) -> list.find("li").length <= 1

set_todo = (options) ->
	method = "POST"
	url = "/todos"
	if options.id?
		method = "PUT"
		url = "/todos/"+options.id

	options.category ?= "unfiled"
	
	jQuery.ajax
		method: method
		url: url
		data:
			id: options.id
			category: options.category
			message: options.message
			date: options.date
		dataType: "json"
		success: options.success
		
complete_todo = (options) ->
	jQuery.ajax
		method: "PATCH"
		url: "/todos/"+options.id
		data:
			id: options.id
			completed: true
			
delete_todo = (options) ->
	jQuery.ajax
		method: "DELETE"
		url: "/todos/"+options.id
		data:
			id: options.id
			success: options.success
					
poll = ->
	jQuery.ajax
		method:"POST"
		url:"/todos/update_todos"
		dataType:"json"
		success: (updates) ->
			category = active_category()
			if category == 'now'
				for completed in updates.completed
					fade_out find_todo(completed)
				for current in updates.current
					add_todo_directly current.id,current.message
			else if category == 'scheduled'
				for current in updates.current
					fade_out(get_date_list(get_todo_date(find_todo(current.id))))


create_todo_item= (category,content,id,date)->
	#outside
	base = $("<li class='todo'></li>")
	base.attr("todo_id",id) if id?
	base.attr("date",date) if date?

	#inside	
	wrapper = $("<div class='wrapper'></div>").text(content).appendTo base
	if category == "unfiled"
		cancel = $("<div class='deleteme' delete_id='"+id+"'></div>").appendTo wrapper
		deletable(cancel)
	else if category == "now"
		complete = $("<div class='completeme' complete_id='"+id+"'></div>").appendTo wrapper
		completable(complete)

	return base

add_todo_directly = (id,content,date) ->
	category = active_category()

	todo_list = $("ul.todos")
	if category == "scheduled"
		todo_list = get_or_create_date_list date

	base = create_todo_item category,content,id,date
	base.appendTo todo_list
	slip_in base,800

	todo_draggable(base)
	
add_clone_func = (obj) ->
	id = obj.attr("todo_id")
	text = obj.text()
	date = obj.attr("date")
	return ->
		add_todo_directly id,text,date
		
new_todo = (category,message,id) ->
	accept = (date)->
		set_todo
			id: id
			message: message
			category: category
			date: date
			success: (data)->
				if active_category() == category
					add_todo_directly data.id,message,date
	revert = ->
		set_todo
			message: message
			success: (data)->
				wiggle($("#unfiled"))
	if category == "scheduled"
		do_calendar(accept,revert)
	else
		accept()

new_todo_from_helper = (helper,landing) ->
	message = helper.text()
	category = $(landing).attr("id")
	id = helper.attr("todo_id")
	new_todo category,message,id

remove_todo=  (todo) ->
	slowly_hide(todo)
	if active_category() == "scheduled"
		date = get_todo_date(todo)
		date_list = get_date_list(date)
		if will_list_be_empty date_list
			remove_date_list date_list

create_date_list = (date) ->
	date_list = $("<ul class='date' id='"+date+"'></ul>").appendTo $("ul.todos")
	header = $("<header></header>").appendTo date_list
	h1 = $("<h1>"+(new Date(parseInt(date)).toLocaleDateString())+"</h1>").appendTo header
	slip_in date_list,400
	return date_list
	
get_or_create_date_list = (date) ->
	date_list = get_date_list date
	if date_list.length == 0
		date_list = create_date_list date
	return date_list	
	
remove_date_list = (list) -> 
	list.attr("id","")
	slip_away list

deletable = (obj) ->
	obj.click ->
		id = $(this).attr("delete_id")
		delete_todo
			id: id
			success: ->
				explode_away $(".todo[todo_id="+id+"]")	

completable = (obj) ->
	obj.click ->
		id = $(this).attr("complete_id")
		todo = $(".todo[todo_id="+id+"]")
		todo.draggable("destroy")
		wrapper = todo.find(".wrapper")

		old_width = wrapper.width()
		old_color = wrapper.css("background-color")

		todo.addClass "completed"

		new_width = wrapper.width()
		new_color = wrapper.css("background-color")

		wrapper.css("width",old_width)
		wrapper.css("background-color",old_color)
		
		wrapper.animate
			backgroundColor: new_color
			width: new_width
			,
			duration: 1000
			easing: "easeInBack"

		complete_todo
			id: id

clear_todo_form = ->
	$(".new_todo").removeClass("todo")
	clear_form($(".todo_message"))

clear_form = (form)->
	message = form.val()
	form.val("")
	return message

do_calendar = (accept,revert)->
	today = new Date()
	tomorrow = new Date()
	tomorrow.setDate(today.getDate() + 1)

	$("#calendar").datepicker
		"minDate": new Date(tomorrow)
		"onSelect": (date)->
			accept(date)
			finish_calendar()
		"dateFormat": "@"
	$("#overlay").fadeIn(400).click -> 
		revert()
		finish_calendar()
	$("#wrapper2").click (event) ->
		event.stopPropagation()

finish_calendar = ->
	$("#overlay").fadeOut(400).unbind("click")
	$("#calendar").datepicker("destroy")

todo_draggable = (obj) ->
	obj.draggable
		cancel: ".deleteme,.completeme"
		helper: "clone"
		appendTo: "body"
		start: (event,ui) ->
			remove_todo $(this)
			ui.helper.addClass("floating")
		stop: (event,ui) ->	
			ui.helper.removeClass("floating")

		revert: (isValidDrop)->
			if !isValidDrop
				setTimeout (add_clone_func $(this)),200
				$(this).remove()
				return true
			return false
		revertDuration: 200

make_todo= (obj) ->
	obj.addClass("todo")
	obj.draggable
		helper: ->
			message = clear_todo_form()
			helper = create_todo_item active_category(),message
			helper.addClass("floating")
		stop: (event,ui)->	
			unmake_todo obj
		revert: true
		revertDuration: 200
		
unmake_todo= (obj) ->
	obj.draggable("destroy");
	obj.removeClass("todo")


transforming_input= (input) ->
	input.keyup ->
		unless is_input_empty $(this)
			make_todo $(".new_todo")
		else
			unmake_todo $(".new_todo")


form_behavior = (form) ->
	form.submit (event) ->
		event.preventDefault()
		message = clear_todo_form()
		category = $(".active").attr("id")
		new_todo category,message

active_droppable= (obj) ->
	obj.droppable
		accept: ".new_todo"
		drop: (event,ui) ->
			new_todo_from_helper(ui.helper,this)
		hoverClass: "targeted"
		activeClass: "targetable"
		
inactive_droppable= (obj) ->
	obj.droppable	
		drop: (event,ui) ->
			wiggle $(this)
			new_todo_from_helper(ui.helper,this)
			ui.helper.remove()
		hoverClass: "targeted"
		activeClass: "targetable"

jQuery ->
	$("#overlay").hide()

	transforming_input $(".todo_message")
	form_behavior $(".active form")
		
	todo_draggable($(".todo:not(.completed)"))
	
	deletable $(".deleteme")
	completable $(".completeme")
		
	active_droppable $(".active")
	inactive_droppable $(".inactive")
			
	setInterval(poll,15000)
		