define ["jquery","cs!descanso"], ($, descanso) ->
    class App extends descanso.App
        
        constructor: ->
            super    
            @api_url = "/api"
            @name = "demo"

        run: ->
            @loadResources (app)=>
                
                selectorview = new descanso.ResourceListView app.resources._resources
                selectorview.setTemplate {view: "template-resourcelist", items: "template-resourcelist-item"}
                reslist = []
                for name, res of app.resources
                    reslist.push res unless name == "_resources"

                selectorview.bind reslist
                selectorview.bindEvent "select", (args) =>
                    @load args.view.obj.name

                app.renderView "#resource_list", selectorview
                
        load: (resource_name) ->
            paneview = new descanso.ResourcePaneView app.resources[resource_name]
            if resource_name == "image"
                paneview.setTemplate "embed-image"
                paneview.bindEvent "attach", (args)=>
                    onupload = (res)=>
                        @load resource_name
                    paneview.elem.upload args.extra.url, onupload, "json"
            else
                paneview.setTemplate "template-entitypane"
            $("#entity_pane").empty()
            
            paneview.bindEvent "submitted", (args)=>
                @load resource_name

            paneview.bindEvent "choose", (args)=>
                res = app.resources[args.extra.resource]
                field = args.extra.field
                obj = args.view.obj
                res.list (obj_list)->
                    chooserview = new descanso.ResourceListView res
                    chooserview.setTemplate { view: "template-chooser", items: "template-chooser-item"}
                    chooserview.bind obj_list
                    app.renderView "#chooser", chooserview
                    chooserview.bindEvent "select", (args)->
                        obj[field] = args.view.obj
                

            listview = new descanso.ResourceListView app.resources[resource_name]
            listview.setTemplate {view: "template-entitylist", items: "template-entitylist-item"}
            
            app.resources[resource_name].list (obj) ->
                listview.bind obj
                listview.bindEvent "new", () ->
                    paneview.bind paneview.resource.empty()
                    paneview.triggerEvent "edit"
                    app.renderView "#entity_pane", paneview
                    
                listview.bindEvent "select", (args) ->
                    paneview.bind args.view.obj
#                    paneview.elem.addClass "new"
                    app.renderView "#entity_pane", paneview
                    
                app.renderView "#entity_list", listview

                
    return { "App": App }