define ['jquery', 'cs!notifier', 'jquery.tmpl.min', 'jquery.upload-1.0.2.min'], ($, notifier) ->
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
            @type = "normal"
            for f in @fields
                if f.upload_url
                    @type="upload"
                    @upload_url = f.upload_url
                @fields_dict[f.name] = f
                
            @repo = {}

        empty: () ->
            dict = {}
            dict[f.name] = null for f in @fields
            return @bless dict

        dict: (obj) ->
            dict = {}
            for f in @fields
                if obj[f.name]? && obj[f.name].id?
                    dict[f.name+"_id"] = obj[f.name].id
                else if obj[f.name]?
                    dict[f.name] = obj[f.name] 
                
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
                list.push @bless obj for obj in data
                callback list

        post: (obj, callback) ->
            @ajax "POST", obj, (data) => callback @bless data

        get: (id, callback) ->
            @ajax "GET", id, (data) => callback @bless data

        put: (obj, callback) ->
            @ajax "PUT", obj, (data) => callback @bless obj

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
                args.data = @dict obj
                
            $.ajax @member_url(obj), args
            
        addToRepo: (obj) ->
            #if @repo[obj.id]
            #    return @repo[obj.id]
            
            obj_notifier = new notifier.Notifier()
            @repo[obj.id] = 
                notifier: obj_notifier 
                entity: obj

        bless: (obj) ->
            #@addToRepo obj
            # Watch object events
            if not obj._notifier?
                obj._notifier = new notifier.Notifier()
                
            for field in @fields
                #Callback to be invoked upon object property setting
                @addHandler obj, field.name, (k, oldval, newval) =>
                    obj._notifier.notifyAll 'change', { path: [k], value: newval }
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
    
    
    class TemplateView
        
        constructor: ()->
            @notifier = new notifier.Notifier()
            @parentView = null
            @subviews = {}
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

        bind: (@obj)->
            # Does nothing for now
            @elem = @element()
            
        ###
        Create and return a DOM element for the given template name
        ###
        element: ( name = "view" ) ->
            @elem = $("#"+@templates[name]).tmpl @
            # Bind view events
            $(@elem).each (i,node) =>
                @createEventBindings node
                $(node).find("[view-bind-event]").each (i,node)=>
                    @createEventBindings node
                            
            # Subview attachment point
            for name, subviews of @subviews
                if @elem.hasClass name
                    attachPoint = @elem
                else
                    attachPoint = @elem.find "." + name
                attachPoint.append sv.elem for sv in subviews

            return @elem
        
        ###
        
        ###
        createEventBindings: (node) ->
            return unless $(node).attr("view-bind-event")
            keyval = (str)->
                sep = str.indexOf(":")
                return [str.substring(0,sep), str.substring(sep+1)]
            
            tokens = $(node).attr("view-bind-event").split(" ")
            [domEvent, viewEvent] = keyval tokens.shift()

            extra = {}
            while tokens.length >0
                [k, v] = keyval tokens.shift()
                extra[k] = v

            $(node).bind domEvent, (event)=> 
                console.log "Triggering dom->view event ", domEvent, viewEvent
                @triggerEvent viewEvent, { view: @, extra: extra }
            

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
                
    ###
    ResourceViews are views that are associated
    to a single specific resource
    ###
    class ResourceView extends TemplateView
        
        constructor: (@resource) ->
            super 
            
        bind: (@obj) ->
            @elem = @element()
            return unless @obj?
            
            embedView = (node, embedId, subview, obj) =>
                #subview = new ResourceView(@resource.app.resources[subresource])
                subview.setTemplate embedId
                subview.bind obj
                $(node).addClass embedId
                @attachView embedId, [subview]
                $(node).empty()
                $(node).append subview.elem

            updateNode = (node, obj, field) =>
                if subresource = @resource.fields_dict[field]?.to
                    # Foreign Key. Embedded subview should be used
                    # rebuild subview
                    embedView node, "embed-"+subresource, new ResourceView(@resource.app.resources[subresource]), obj           
                else if node.tagName == "INPUT"
                    $(node).val obj
                else
                    $(node).text obj
                    
            # HACK - This prevents setting a domUpdater directed towards the
            # resource repo when the resource is the meta resource 
            # (_resources) :/
            if obj._notifier
                domUpdater = () =>
                    return {
                        "change" : (args) =>
                            console.log "Updating element"
                            field = args.path[0]
                            $(@elem).find('[bind="'+field+'"]').each (i,node) -> updateNode node, args.value, field
                    }
                obj._notifier.addListener domUpdater @elem

            bindNode = (i, node) =>
                tagName = node.tagName
                return unless $(node).attr("bind")?
                path = $(node).attr("bind").trim().split(" ")
                path_cpy = path.slice(0) # A copy of the array
                #target = obj

                #Initialize element
                #while path.length > 1
                #    target = target[path.shift()]
                # Suppporting 1-length paths for now
                field = path.shift()

                updateNode node, obj[field], field
                                    
#                if @resource.fields_dict[field].upload_url
#                    subview = new FieldView(@resource.fields_dict[field])
#                    subview.bindEvent "attach", (args)->
#                        onupload = (res)->
#                            alert("uploaded")
                        #subview.elem.find('input[type=file]').upload args.extra.url, onupload, "json"
#                    embedView node, "fileupload", subview
#                else    
                $(node).bind 'change', (event) =>
                    @updateObject { path: path_cpy , value: $(event.target).val() }
            
            $(@elem).each bindNode
            $(@elem).find("[bind]").each bindNode
            
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

    class ResourcePaneView extends ResourceView
        
        constructor: (resource) ->
            super resource
        
        bind: (obj) ->
            super obj
            elem = @elem
            resource = @resource
            
            # Bind DOM events
            @bindEvent "edit", (args)=> @editMode()
            @bindEvent "canceledit", (args)=> @normalMode()

            @bindEvent "submit", (args) =>            
                elem.removeClass "editmode"
                elem.addClass "submitmode"
                if obj.id
                    resource.put obj, ()=>
                        elem.removeClass "submitmode"
                        @triggerEvent "submitted"
                else
                    resource.post obj, ()->
                     elem.removeClass "submitmode"
           
            @bindEvent "delete", (args) =>
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