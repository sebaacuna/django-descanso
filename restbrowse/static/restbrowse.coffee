define ["jquery","cs!descanso"], ($, descanso) ->
    class App extends descanso.App        
        
        constructor: ->
            super    
            @api_url = "/api"
            @name = "demo"

        run: ->
            @loadResources (app)=>
                
                selectorview = new descanso.ResourceListView app.resources._resources
                selectorview.setTemplate {view: "template-resourcelist", items: "template-resourcelistitem"}
                reslist = []
                for name, res of app.resources
                    reslist.push res unless name == "_resources"

                selectorview.bind reslist
                selectorview.bindEvent "select", (obj) =>
                    @load obj.name

                app.renderView "#resource_list", selectorview
                
        load: (resource_name) ->
            paneview = new descanso.ResourcePaneView app.resources[resource_name]
            paneview.setTemplate "template-entitypane"
            $("#entity_pane").empty()

            listview = new descanso.ResourceListView app.resources[resource_name]
            listview.setTemplate {view: "template-entitylist", items: "template-entitylistitem"}
            
            app.resources[resource_name].list (obj) ->
                listview.bind obj
                listview.bindEvent "new", () ->
                    paneview.bind paneview.resource.empty()
                    paneview.editMode()
                    app.renderView "#entity_pane", paneview
                    
                listview.bindEvent "select", (obj) ->
                    paneview.bind obj
                    paneview.elem.addClass "new"
                    app.renderView "#entity_pane", paneview
                    
                app.renderView "#entity_list", listview

                
    return { "App": App }