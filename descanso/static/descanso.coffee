define ['jquery', 'cs!notifier'], ($, notifier) ->
    class App
        
        constructor: ->
            @resources = {}
            @server_url = ''
            @api_url = ''
            @meta_resources_url = "/_resources"
            
        printRepo: () ->
            for own name, r of @resources
                console.log "<", name , ">"
                for own id, obj of r.repo
                    console.log ">> ", obj.id, ":", obj.name
        
        addResource: (metadata, cls) ->
            if !cls
                cls = Resource
            @resources[metadata.name] = new cls( @server_url, metadata)

        renderView: ( selector, view ) ->
            elem = $(selector)
            elem.empty()
            elem.append(view.elem)

        loadResources: ( callback ) ->
            $.ajax @server_url + @api_url + @meta_resources_url,
                success: (data, textStatus, jqXHR) =>
                    for res in data
                        @addResource res
                    callback(app)
                dataType: "json"

        @objectUpdater: (target) ->
            return {
                "change": (args) ->
                    console.log "Updating object"
                    obj = target
                    i = 0
                    while i < args.path.length - 1
                        obj = obj[args.path[i++]]
                    obj[args.path[i]] = args.value
                }

        @domUpdater: (target) ->
            return {
                "change" : (args) ->
                    console.log "Updating element"
                    $(target).find('[bind="'+args.path.join(" ")+'"]').each (i,node) ->
                        if node.tagName == "INPUT"
                            $(node).val args.value
                        else
                            $(node).text args.value
            }

        @bind: (view, obj) ->

#            dom_notifier    = new notifier.Notifier()

#            object_notifier     = new notifier.Notifier()
#            object_updater     = @objectUpdater obj

#            dom_notifier.addListener object_updater
#            object_notifier.addListener @domUpdater view.elem

            # Find all bindable nodes under the root binding element


            
    class Resource
        
        constructor: (@server_url, metadata) ->
            @name = metadata.name
            @url = metadata.url
            @fields = metadata.fields
            @repo = {}

        empty: () ->
            dict = {}
            dict[f.name] = null for f in @fields
            return dict

        dict: (obj) ->
            dict = {}
            dict[f.name] = obj[f.name] for f in @fields
            return dict
            
        member_url: (obj_or_id) ->
            if typeof obj_or_id == 'object'
                if obj_or_id.id
                    id = obj_or_id.id
                else
                    return @server_url + @url
            else
                id = obj_or_id
                
            return @server_url + [@url, id ].join "/"

        list: (callback) ->
            @ajax "GET", "", (data) =>
                list = []
                list.push @entity obj for obj in data
                callback list

        post: (obj, callback) ->
            @ajax "POST", obj, (data) =>
                #@repo[data.id] = data
                callback @entity data

        get: (id, callback) ->
            @ajax "GET", id, (data) =>
                #@repo[id] = data
                callback @entity data

        put: (obj, callback) ->
            @ajax "PUT", obj, (data) =>
                #@repo[obj.id] = obj
                #@entity obj
                callback obj

        delete: (obj, callback) ->
            @ajax "DELETE", obj, (data) =>
                delete @repo[obj .id]
                callback obj
                
        ajax: (method, obj, callback) ->
            args =
                success: (data, textStatus, jqXHR) ->
                    callback data
                type: method
                dataType: if method == 'PUT' then 'text' else 'json'

            if typeof obj == 'object'
                args.data = @dict(obj)
                
            $.ajax @member_url(obj), args
            
            
        entity: (obj) ->
            
            if @repo[obj.id]
                return @repo[obj.id]
            
            obj_notifier = new notifier.Notifier()
            @repo[obj.id] = 
                notifier: obj_notifier 
                entity: obj
            
            # Watch object events
            for field in @fields
                #Callback to be invoked upon object property setting
                @addHandler obj, field.name, (k, oldval, newval) ->
                    obj_notifier.notifyAll 'change', { path: [k], value: newval }
                    return newval
            
            return obj


        #Adds getter/setters to an object    
        addHandler: (obj, prop, handler) ->
            oldval = obj[prop]
            newval = oldval
            getter = () -> return newval
            setter = (val) ->
                if typeof prop == 'function' 
                    return #HACK
                oldval = newval
                return newval = handler prop, oldval, val

            if delete obj[prop] # can't watch constants
                if obj.defineProperty # ECMAScript 5
                    obj.defineProperty obj, prop,
                        get: getter
                        set: setter
                        enumerable: false
                        configurable: true
                else if obj.__defineGetter__ && obj.__defineSetter__ # legacy
                    obj.__defineGetter__ prop, getter
                    obj.__defineSetter__ prop, setter
    
    ###
    ResourceViews are views that are associated
    to a single specific resource
    ###
    class ResourceView
        
        constructor: (@resource) ->
            @fields = @resource.fields
            
        bind: (@obj) ->
            domUpdater = () =>
                return {
                    "change" : (args) =>
                        console.log "Updating element"
                        $(@elem).find('[bind="'+args.path.join(" ")+'"]').each (i,node) ->
                            if node.tagName == "INPUT"
                                $(node).val args.value
                            else
                                $(node).text args.value
                }
            @resource.repo[obj.id].notifier.addListener domUpdater @elem
            
            @elem.find("[bind]").each (i, node) =>
                tagName = node.tagName
                node = $(node)
                path = node.attr("bind").trim().split(" ")
                path_cpy = path.slice(0) # A copy of the array
                target = obj

                #Initialize element
                while path.length > 1
                    target = target[path.shift()]
                key = path.shift()

                if tagName == "INPUT"
                    node.val target[key]

                    # Set listeners from DOM to monitored obejct
                    node.bind 'change', (event) =>
                        @updateObject { path: path_cpy , value: $(event.target).val() }
                else
                    node.text target[key]
        
        updateObject: (args) ->
            console.log "Updating object"
            obj = @obj
            i = 0
            while i < args.path.length - 1
                obj = obj[args.path[i++]]
            obj[args.path[i]] = args.value
            

    class ResourceListItemView extends ResourceView
        
        constructor: (resource) ->
            super resource
            
            @elem = $("<tr>")
            for field, i in resource.fields
                @elem.append $("<td>").attr "bind", field.name
                
        bind: (obj) ->
            @elem.attr "id", obj.id
            super obj

    
    class ResourceListView extends ResourceView
        
        constructor: (resource) ->
            super resource
            
#            @entities = {}

            headrow = $("<tr>")
            for field, i in resource.fields
                headrow.append $("<th>").text(field.name)
                
            thead = $("<thead>").append headrow
            @tbody = $("<tbody>")
            @elem = $("<table>").addClass "resourcelist view"
            @elem.append thead, @tbody
            
        bind: (obj_list) ->
            view = @
            for obj in obj_list
#                @entities[obj.id] = obj
                rowview = new ResourceListItemView(@resource)
                rowview.bind obj
                rowview.elem.bind "click", (event)->
                    view.onSelect obj
                @tbody.append rowview.elem


    class ResourcePaneView extends ResourceView
        
        constructor: (resource) ->
            super resource
            @elem = $("<form />").addClass "resourcepane view"

            for field, i in resource.fields
                row = $("<div />").addClass("property")
                @elem.append row
                row.append $("<div>"    ).addClass("fieldName").text( field.verbose_name )
                row.append $("<input>"  ).attr("bind", field.name).addClass("valueInput")
                row.append $("<div>"    ).attr("bind", field.name).addClass("valueDisplay")
                    
            @elem.append $("<div>").addClass("controls").append(
                $("<a/>").addClass("edit").text("Edit")
                $("<a/>").addClass("submit").text("Submit")
                $("<a/>").addClass("cancel").text("Cancel")
                $("<a/>").addClass("delete").text("Delete")
            )
        
        bind: (obj) ->
            elem = @elem
            resource = @resource
            elem.find(".controls a.edit"   ).bind "click", ()->    elem.addClass "editmode"
            elem.find(".controls a.cancel" ).bind "click", () ->   elem.removeClass "editmode"

            elem.find(".controls a.submit").bind "click", () ->            
                elem.removeClass "editmode"
                elem.addClass "submitmode"
                if obj.id
                    resource.put obj, ()->
                        elem.removeClass "submitmode"
                else
                    resource.post obj, ()->
                        elem.removeClass "submitmode"
                                
            elem.find('.controls a.delete').bind "click", () ->
                elem.removeClass "editmode"
                elem.addClass "submitmode"
                resource.delete obj, ()=>
                    @bind(resource.empty())
                    elem.removeClass "submitmode"

            super obj

    return {
        "App": App
        "ResourcePaneView": ResourcePaneView
        "ResourceListView": ResourceListView
    }