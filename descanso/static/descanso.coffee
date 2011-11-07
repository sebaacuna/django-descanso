define ['jquery', 'cs!notifier', "object.watch"], ($, notifier) ->
    class App
        
        constructor: ->
            @resources = {}
            @server_url = ''
            @api_url = ''
            @meta_resources_url = "/_resources"
        
        addResource: (metadata, cls) ->
            if !cls
                cls = Resource
            @resources[metadata.name] = new cls( @server_url, metadata)

        bind: (elem, obj) ->

            dom_notifier    = new notifier.Notifier()
            dom_updater     = @domUpdater(elem)
            
            object_notifier     = new notifier.Notifier()
            object_updater     = @objectUpdater(obj)
            
            dom_notifier.addListener(object_updater)
            object_notifier.addListener(dom_updater)
            
            # Find all bindable nodes under the root binding element
            $("#"+elem.attr("id") + " [bind]").each (i, node) ->
                path = $(node).attr("bind").trim().split(" ")
                path_cpy = path.slice(0) # A copy of the array
                target = obj
                
                #Initialize element
                while path.length > 1
                    target = target[path.shift()]

                key = path.shift()
                $(node).val(target[key])

                # Set listeners from DOM to monitored obejct
                $(node).bind 'change', (event) ->
                    dom_notifier.notifyAll 'change', { path: path_cpy , value: $(event.target).val() }
                    
            
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
                    while i < args.path.length - 1
                        obj = obj[args.path[i++]]
                    obj[args.path[i]] = args.value
                }
        
        domUpdater: (target) ->
            return {
                "change" : (args) ->
                    console.log "Updating element"
                    $('#'+target.attr("id") + ' [bind="'+args.path.join(" ")+'"]').val(args.value)
            }
            
        formRender: ( resource, id ) ->
            app = @
            resource = @resources[resource]
            resource.get id, (obj) ->
                form = app.objectForm obj
                form.append $("<div>").addClass("descanso-form-controls").append $('<input type="button" value="Send"/>').bind "click", (event)->
                    resource.put obj

                form.attr "id", app.name 
                $("#"+app.name).replaceWith form 
                app.bind form, obj

        objectForm: (obj) ->
            form = $("<form />").addClass("descanso-form")
            for own key of obj
                row = form.append $("<div />").addClass("descanso-form-property")
                row.append $("<div />").addClass("descanso-form-key").text( key )
                row.append $("<div />").addClass("descanso-form-value").append $("<input />").attr("bind", key)
            return form

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
            @cache = {}

        dict: (obj) ->
            dict = {}
            dict[f.name] = obj[f.name] for f in @fields
            return dict
            
        member_url: (id) ->
            return @server_url + [@url, id ].join "/"
        
        get: (id, callback) ->

            cache = @cache
            $.ajax @member_url(id),
                success: (data, textStatus, jqXHR) ->
                    cache[id] = data
                    callback data
                dataType: "json"
                    
        put: (obj, callback) ->
            cache = @cache
            $.ajax @member_url(obj.id),
                data: @dict(obj)
                success: (data, textStatus, jqXHR) ->
                    cache[id] = data
                    callback data
                dataType: "json"
                type: "PUT"            

    return  { "App": App }