define ['jquery', 'cs!notifier', 'jquery.tmpl.min'], ($, notifier) ->
    class App
        
        constructor: ->
            @resources = {}
            @server_url = ''
            @api_url = ''
            @meta_resources_url = "/_resources"
            
        addResource: (metadata, cls) ->
            if !cls
                cls = Resource
            @resources[metadata.name] = new cls( @, metadata)

        renderView: ( selector, view ) ->
            elem = $(selector)
            elem.empty()
            elem.append(view.elem)

        loadResources: ( callback ) ->
            meta_url = @server_url + @api_url + @meta_resources_url
            # Meta-resource
            delete @resources["_resources"]
            @addResource
                name: '_resources'
                url: meta_url
                fields: [
                    { name: "name"},
                    { name: "fields"},
                    { name: "url" },
                ]
            $.ajax meta_url,
                success: (data, textStatus, jqXHR) =>
                    for res in data
                        @addResource res
                    callback(app)
                dataType: "json"
            
    class Resource
        
        constructor: (@app, metadata) ->
            @server_url = @app.server_url
            @id = metadata.name
            @name = metadata.name
            @url = metadata.url
            @fields = metadata.fields
            @fields_dict = {}
            @fields_dict[f.name] = f for f in @fields
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
            @ajax "POST", obj, (data) => callback @entity data

        get: (id, callback) ->
            @ajax "GET", id, (data) => callback @entity data

        put: (obj, callback) ->
            @ajax "PUT", obj, (data) => callback obj

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
            
        addToRepo: (obj) ->
            if @repo[obj.id]
                return @repo[obj.id]
            
            obj_notifier = new notifier.Notifier()
            @repo[obj.id] = 
                notifier: obj_notifier 
                entity: obj

        entity: (obj) ->
            @addToRepo obj
            # Watch object events
            for field in @fields
                #Callback to be invoked upon object property setting
                @addHandler obj, field.name, (k, oldval, newval) =>
                    @repo[obj.id].notifier.notifyAll 'change', { path: [k], value: newval }
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
            @subviews = {}
            @parentView = null
            @notifier = new notifier.Notifier()
            @templates = {}
        
        ###
        Expect a dictionary of { template_name: template_id }
        template_name is one of the names relevant to the view
        template_id is the id of the template container on the DOM
        
        If only a template id is received, the template name "view" is 
        inferred
        ###
        setTemplate: (templates) ->
            if typeof templates == "object"
                @templates = templates
            else
                @templates['view'] = templates

            
        ###
        Create and return a DOM element for the given template name
        ###
        element: ( name = "view" ) ->
            @elem = $("#"+@templates[name]).tmpl @
            # Subview attachment point
            for name, subviews of @subviews
                if @elem.hasClass name
                    attachPoint = @elem
                else
                    attachPoint = @elem.find "." + name
                attachPoint.append sv.elem for sv in subviews
            return @elem
            
            
        bind: (@obj) ->
            @elem = @element()

            updateNode = (node, obj, field) =>
                if subresource = @resource.fields_dict[field].to
                    # Foreign Key. Embedded subview should be used
                    # rebuild subview
                    subview = new ResourceView(@resource.app.resources[subresource])
                    subview.setTemplate "embed-"+subresource
                    subview.bind obj
                    embedClass = "embed-"+subresource
                    $(node).addClass embedClass
                    @attachView embedClass, [subview]
                    $(node).empty()
                    $(node).append subview.elem
                    
                else if node.tagName == "INPUT"
                    $(node).val obj
                else
                    $(node).text obj
                    
            # HACK - This prevents setting a domUpdater directed towards the
            # resource repo when the resource is the meta resource 
            # (_resources) :/
            if @resource.repo[obj.id]
                domUpdater = () =>
                    return {
                        "change" : (args) =>
                            console.log "Updating element"
                            field = args.path[0]
                            $(@elem).find('[bind="'+field+'"]').each (i,node) -> updateNode node, args.value, field
                    }
                @resource.repo[obj.id].notifier.addListener domUpdater @elem

            bindNode = (i, node) =>
                tagName = node.tagName
                return unless $(node).attr("bind")?
                path = $(node).attr("bind").trim().split(" ")
                path_cpy = path.slice(0) # A copy of the array
                target = obj

                #Initialize element
                #while path.length > 1
                #    target = target[path.shift()]
                # Suppporting 1-length paths for now
                key = path.shift()

                updateNode node, target[key], key
                $(node).bind 'change', (event) =>
                    @updateObject { path: path_cpy , value: $(event.target).val() }


            
            $(@elem).each bindNode
            $(@elem).find("[bind]").each bindNode
            
            # Bind view events
            $(@elem).find("[view-bind-event]").each (i, node)=>
                tokens = $(node).attr("view-bind-event").split(" ")
                [domEvent, viewEvent] = tokens.shift().split(":")

                extra = {}
                while tokens.length >0
                    [k, v] = tokens.shift().split(":")
                    extra[k] = v

                $(node).bind domEvent, ()=> @triggerEvent viewEvent, { obj: @obj, extra: extra }
            
        bindEvent: (event, handler) ->
            @notifier.on event, handler
            
        triggerEvent: (event, arg) ->
            @notifier.notifyAll event, arg

        attachView: (name, subview) ->
            if subview instanceof Array
                @subviews[name] = []
                @attachView name, sv for sv in subview
            else
                @subviews[name] ?= []
                @subviews[name].push subview
                subview.setTemplate @templates[name]
                subview.parentView = @
        
        updateObject: (args) ->
            console.log "Updating object"
            obj = @obj
            i = 0
            #while i < args.path.length - 1
            #    obj = obj[args.path[i++]]
            # Suppporting 1-length paths for now
            obj[args.path[i]] = args.value
            

    class ResourceListItemView extends ResourceView
        
        constructor: (resource) ->
            super resource
        
        bind: (obj) ->
            super obj
            @elem.attr "id", obj.id
            @bindEvent "select", (args)=>
                if @parentView
                    @parentView.triggerEvent "select", args

    class ResourceListView extends ResourceView
        
        constructor: (resource) ->
            super resource
        
        bind: (obj_list) ->
            for obj in obj_list
                rowview = new ResourceListItemView(@resource)
                @attachView "items", rowview
                rowview.bind obj
            @elem = @element()
            @elem.find(".add").bind "click", () =>
                @triggerEvent "new"

    class ResourcePaneView extends ResourceView
        
        constructor: (resource) ->
            super resource
        
        bind: (obj) ->
            super obj
            elem = @elem
            resource = @resource
            
            # Bind DOM events
            elem.find(".controls a.edit"   ).bind "click", ()=> @editMode()
            elem.find(".controls a.cancel" ).bind "click", ()=> @normalMode()

            elem.find(".controls a.submit").bind "click", () =>            
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
            
        editMode: ->
            @elem.addClass "editmode"
        
        normalMode: ->
            @elem.removeClass "editmode"

    return {
        "App": App
        "ResourcePaneView": ResourcePaneView
        "ResourceListView": ResourceListView
    }