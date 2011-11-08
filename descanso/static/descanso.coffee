define ['jquery', 'cs!notifier', "object.watch"], ($, notifier) ->
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

        bind: (view, obj) ->
            view.bind obj
            
            dom_notifier    = new notifier.Notifier()
            dom_updater     = @domUpdater(view.elem)
            
            object_notifier     = new notifier.Notifier()
            object_updater     = @objectUpdater(obj)
            
            dom_notifier.addListener(object_updater)
            object_notifier.addListener(dom_updater)
            
            # Find all bindable nodes under the root binding element
            view.elem.find("[bind]").each (i, node) ->
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
                    node.bind 'change', (event) ->
                        dom_notifier.notifyAll 'change', { path: path_cpy , value: $(event.target).val() }
                else
                    node.text target[key]

            
            # Watch object events
            fields = []
            fields.push k for own k of obj
            for k in fields
                obj.watch k, (k, oldval, newval) ->
                    object_notifier.notifyAll 'change', { path: [k], value: newval }
                    return newval
            
        objectUpdater: (target) ->
            return {
                "change": (args) ->
                    console.log "Updating object"
                    obj = target
                    i = 0
                    while i < args.path.length - 1
                        obj = obj[args.path[i++]]
                    obj[args.path[i]] = args.value
                }
        
        domUpdater: (target) ->
            return {
                "change" : (args) ->
                    console.log "Updating element"
                    $(target).find('[bind="'+args.path.join(" ")+'"]').each (i,node) ->
                        if node.tagName == "INPUT"
                            $(node).val(args.value)
                        else
                            $(node).text(args.value)
            }
            
        formRender: ( resource, id ) ->
            app = @
            resource = @resources[resource]
            resource.get id, (obj) ->
                view = new ResourcePaneView(resource)
                view.elem.attr "id", app.name 
                $("#"+app.name).replaceWith view.elem
                app.bind view, obj


        loadResources: ( callback ) ->
            app = @
            $.ajax @server_url + @api_url + @meta_resources_url,
                success: (data, textStatus, jqXHR) ->
                    for res in data
                        app.addResource res
                    callback()
                dataType: "json"

            
    class Resource
        
        constructor: (@server_url, metadata) ->
            @name = metadata.name
            @url = metadata.url
            @fields = metadata.fields
            @repo = {}

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


        post: (obj, callback) ->
            r =@
            @ajax "POST", obj, (data) ->
                r.repo[data.id] = data
                callback data

        get: (id, callback) ->
            r = @
            @ajax "GET", id, (data) ->
                r.repo[id] = data
                callback data

        put: (obj, callback) ->
            r = @
            @ajax "PUT", obj, (data) ->
                r.repo[obj.id] = obj
                callback data

        delete: (obj, callback) ->
            r = @
            @ajax "DELETE", obj, (data) ->
                delete r.repo[obj.id]
                callback data
                
        ajax: (method, obj, callback) ->
            args =
                success: (data, textStatus, jqXHR) ->
                    callback data
                type: method
                dataType: if method == 'PUT' then 'text' else 'json'

            if typeof obj == 'object'
                args.data = @dict(obj)
                
            $.ajax @member_url(obj), args

    
    class ResourcePaneView
        
        constructor: (@resource) ->
            @elem = $("<form />").addClass "descanso"
            for field, i in @resource.fields
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
                resource.put obj, ()->
                    elem.removeClass "submitmode"            
                                
            elem.find('.controls a.delete').bind "clicks", () ->
                elem.removeClass "editmode"
                elem.addClass "submitmode"
                resource.delete obj, ()->
                    elem.removeClass "submitmode"

    return  { "App": App }