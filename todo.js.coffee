animations = 
	explodeAway: (obj,finish) ->
		obj.stop()
		obj.effect 
			effect: "explode"
			pieces: 100
			complete: ->
				obj.show().css("opacity",0).slideUp
					duration: 500
					complete: finish
	
	slowlyHide: (obj,finish) ->
		obj.stop().css("opacity",0).slideUp 500, ->
			obj.css("opactity",1)
			finish()

	slipAway: (obj) ->
		obj.stop().slideUp 600, ->
			list.remove()

	slipIn: (obj,time) ->
		obj.stop().hide().slideDown(time)

	fadeOut: (obj) ->
		obj.stop().animate {opacity:0},
			complete: ->
				obj.slideUp
					complete: ->
						obj.remove()
					
	wiggle: (obj) ->
		 obj.stop().animate({"width":250},200).animate({"width":165},200).animate({"width":200},200)

	slowChange: (obj,func) ->
		obj.stop()

		oldWidth = obj.width()
		oldColor = obj.css("background-color")

		func()

		newWidth = obj.width()
		newColor = obj.css("background-color")

		obj.css("width",oldWidth)
		obj.css("background-color",oldColor)

		obj.animate
			backgroundColor: newColor
			width: newWidth
			,
			duration: 1000
			easing: "easeInBack"
		
					
class ToDo
	#creation
	constructor: (@jQueryObj) ->
		@id = @jQueryObj.attr('todo_id')
		@date = @jQueryObj.attr('date')
		@message = @jQueryObj.text()
	
	@create: (message,id,date) ->
		#outside
		base = $("<li class='todo'></li>").text("")
		base.attr("todo_id",id) if id?
		base.attr("date",date) if date?

		#inside	
		wrapper = $("<div class='wrapper'></div>").text(message).appendTo base

		return new ToDo(base)
		
	@findByID: (id) ->
		new ToDo($(".todo[todo_id=#{id}]"))
		
	clone: ->
		ToDo.create(@message,@id,@date)
		
	#basic utility
	remove: ->
		@jQueryObj.remove()

	isNew: ->
		!(@id?)

	setDate: (date) ->
		@date = date
		@jQueryObj.attr('date',date)
		
	setID: (id) ->
		@id = id
		@jQueryObj.attr('todo_id',id)

	getWrapper: ->
		@jQueryObj.find(".wrapper")
	
	# ajax
	serverUrl: ->
 		"/todos/#{@id}"

	createOnServer: (category,onSuccess) ->
		jQuery.ajax
			method: "POST"
			url: "/todos"
			data:
				message: @message
				category: category
				date: @date
			dataType: "json"
			success: (data) =>
				@setID(data.id)
				onSuccess()
	
	setCategoryOnServer: (category,onSuccess) ->
		jQuery.ajax
			method: "PATCH"
			url: @serverUrl()
			data:
				category: category
				date: @date
			dataType: "json"
			complete: onSuccess
			
	completeOnServer: (onSuccess) ->
		jQuery.ajax
			method: "PATCH"
			url: @serverUrl()
			data:
				completed: true
			success: onSuccess
				
	deleteFromServer: (onSuccess) ->
		jQuery.ajax
			method: "DELETE"
			url: @serverUrl()
			success: onSuccess
	
	#status effects
	makeFloating: ->
		@jQueryObj.addClass("floating")
	
	unmakeFloating: ->
		@jQueryObj.removeClass("floating")
		
	makeDraggable: ->
		@jQueryObj.draggable
			cancel: ".deleteme,.completeme"
			helper: "clone"
			appendTo: "body"
			start: (event,ui) =>
				@helper = new ToDo(ui.helper)
				@helper.makeFloating()
				Category.getActive().removeTodo(this)
			stop: (event,ui) =>	
				@helper.unmakeFloating()

			revert: (isValidDrop)=>
				if !isValidDrop
					setTimeout =>
						Category.getActive().displayTodo(this.clone())
					,
						200
					return true
				return false
			revertDuration: 200
		
	unmakeDraggable: ->
		@jQueryObj.draggable("destroy")
		
	makeDeletable: () ->
		deleteButton = @jQueryObj.find(".deleteme")
		if deleteButton.length == 0
			deleteButton = $("<div class='deleteme' delete_id='#{@id}'></div>").appendTo @getWrapper()

		deleteButton.click =>
			@unmakeDraggable()
			@deleteFromServer =>
				animations.explodeAway @jQueryObj, =>
					this.remove()
				
	makeCompletable: () ->
		completeButton = @jQueryObj.find(".completeme")
		if completeButton.length == 0
			completeButton = $("<div class='completeme' complete_id='#{@id}'></div>").appendTo @getWrapper()
				
		completeButton.click =>
			@unmakeDraggable()
			@completeOnServer =>
				animations.slowChange @getWrapper(), =>
					@jQueryObj.addClass "completed"

class Category
	constructor: (@jQueryObj) ->
		@category = @jQueryObj.attr("id")
		@isActive = @jQueryObj.hasClass('active')
		if @isActive
			@list = new List($("ul.todos"))
			
	@create: (jQueryObj) ->
		switch jQueryObj.attr("id")
			when 'unfiled'
				return new UnfiledCategory(jQueryObj)
			when 'someday'
				return new SomedayCategory(jQueryObj)
			when 'scheduled'
				return new ScheduledCategory(jQueryObj)				
			when 'now'
				return new NowCategory(jQueryObj)
	
	@getActive: ->
		Category.create($(".active"))
	
	@find: (category) ->
		new Category($("##{category}"))
	
	addTodo: (todo) ->
		if todo.id?
			todo.setCategoryOnServer @category, =>
				@displayTodo todo
		else
			todo.createOnServer @category, =>
				@displayTodo todo
		
	displayTodo: (todo) ->
		if @list?
			@list.addTodo todo
			@setProperties todo
		else
			animations.wiggle @jQueryObj
		
	removeTodo: (todo) ->
		if @list?
			@list.removeTodo todo
			
	setProperties: (todo) ->
			
	makeDroppable: ->
		if @isActive
			@makeActiveDroppable()
		else
			@makeInactiveDroppable()
		
	makeActiveDroppable: ->
		@jQueryObj.droppable
			accept: ".new_todo"
			drop: (event,ui) =>
				@addTodo(new ToDo(ui.helper).clone())
			hoverClass: "targeted"
			activeClass: "targetable"
			
	makeInactiveDroppable: ->
		@jQueryObj.droppable
			drop: (event,ui) =>
				@addTodo(new ToDo(ui.helper).clone())
			hoverClass: "targeted"
			activeClass: "targetable"
			
	update: ->
		
class UnfiledCategory extends Category
	setProperties: (todo) ->
		todo.makeDeletable()
		
class SomedayCategory extends Category
	
class ScheduledCategory extends Category
	@calendar:
		start: (accept,revert) =>
			today = new Date()
			tomorrow = new Date()
			tomorrow.setDate(today.getDate() + 1)

			$("#calendar").datepicker
				"minDate": new Date(tomorrow)
				"onSelect": (date)=>
					accept(date)
					ScheduledCategory.calendar.finish()
				"dateFormat": "@"
			$("#overlay").fadeIn(400).click => 
				revert()
				ScheduledCategory.calendar.finish()
			$("#wrapper2").click (event) ->
				event.stopPropagation()
		finish: ->
			$("#overlay").fadeOut(400).unbind("click")
			$("#calendar").datepicker("destroy")
			
	displayTodo: (todo) ->
		if @isActive
			list = DateList.getOrCreate(todo.date,@list)
			list.addTodo todo
		else
			animations.wiggle @jQueryObj
		
	removeTodo: (todo) ->
		list = DateList.get(todo.date)
		list.removeTodo todo
		
	addTodo: (todo) =>
		ScheduledCategory.calendar.start (date) =>
			todo.setDate(date)
			if todo.id?
				todo.setCategoryOnServer @category, =>
					@displayTodo todo
			else
				todo.createOnServer @category, =>
					@displayTodo todo
		,=>
			Category.find('unfiled').addTodo(todo)
			
	update: (updates) ->
		for current in updates.current
			date = ToDo.findByID(current.id).date
			list = DateList.get(date)
			animations.fadeOut(list.jQueryObj)
	
class NowCategory extends Category
	setProperties: (todo) ->
		todo.makeCompletable()
	update: (updates) ->
		for completed in updates.completed
			todo = ToDo.findByID(completed)
			fade_out todo.jQueryObj
		for current in updates.current
			DisplayTodo(current.message,current.id)
	
class List
	constructor: (@jQueryObj) ->
	
	addTodo: (todo) ->
		todo.jQueryObj.appendTo @jQueryObj
		animations.slipIn todo.jQueryObj,800
		todo.makeDraggable()
		
	removeTodo: (todo) ->
		animations.slowlyHide todo.jQueryObj, ->
			todo.jQueryObj.detach()
		
		
class DateList extends List	
	@get: (date) ->
		new DateList($("##{date}"))
		
	@create: (date,parent) ->
		dateList = $("<ul class='date' id='#{date}'></ul>").appendTo parent.jQueryObj
		header = $("<header></header>").appendTo dateList
		h1 = $("<h1>#{(new Date(parseInt(date)).toLocaleDateString())}</h1>").appendTo header
		animations.slipIn dateList,400
		return new DateList(dateList)

	@getOrCreate: (date,parent) ->
		list = DateList.get(date)
		if list.exists()
			return list
		return DateList.create(date,parent)
		
	exists: ->
		return @jQueryObj.length > 0

	isEmpty: ->
		@jQueryObj.find("li").length <= 0

	willBeEmpty: ->
		@jQueryObj.find("li").length <= 1

	removeTodo: (todo) ->
		super
		if @willBeEmpty()
			this.remove()

	remove: ->
		@jQueryObj.attr("id","")
		animations.slipAway @jQueryObj
		
class InputForm
	constructor: (@formObj) ->
		@jQueryObj = @formObj.find(".new_todo")
		@inputObj = @formObj.find("input.todo_message")
	
	isEmpty: ->
		@inputObj.val() == ""
		
	clear: ->
		@jQueryObj.removeClass("todo")
		message = @inputObj.val()
		@inputObj.val("")
		return message
		
	makeToDo: ->
		@jQueryObj.addClass("todo")
		@jQueryObj.draggable
			helper: =>
				message = this.clear()
				helper = ToDo.create(message)
				helper.makeFloating()
				return helper.jQueryObj
			stop: (event,ui)=>	
				@unmakeToDo()
				ui.helper.remove()
			revert: "invalid"
			revertDuration: 200
			
	unmakeToDo: ->
		@jQueryObj.draggable("destroy")
		@jQueryObj.removeClass("todo")
		
	makeTransformable: ->
		self = @
		@formObj.submit (event) =>
			event.preventDefault()
			message = @clear()
			Category.getActive().addTodo(ToDo.create message)
		@inputObj.keyup =>
			unless @isEmpty()
				@makeToDo()
			else
				@unmakeToDo()

poll = ->
	jQuery.ajax
		method:"POST"
		url:"/todos/update_todos"
		dataType:"json"
		success: (updates) ->
			category = Category.getActive()
			category.update(updates)
			if category == 'now'
			else if category == 'scheduled'


jQuery ->
	$("#overlay").hide()

	$(".category").each (index,element) ->
		category = Category.create($(this))
		category.makeDroppable()

	active = Category.getActive()	
	$(".todo:not(.completed)").each (index,element) ->
		todo = new ToDo($(this))
		todo.makeDraggable()
		active.setProperties(todo)

	form = new InputForm($(".active form"))
	form.makeTransformable()

	setInterval(poll,15000)
		