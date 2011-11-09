define ["jquery", "cs!descanso"], ($, descanso) ->
    class Demo extends descanso.App        
        
        constructor: ->
            super    
            @api_url = "/api"
            @name = "demo"

        run: ->
            @loadResources (app)->
                listview = new descanso.ResourceListView(app.resources.person)
                paneview = new descanso.ResourcePaneView(app.resources.person)
                app.resources.person.list (obj) ->
                    listview.bind obj
                    listview.bindEvent "select", (obj) ->
                        paneview.bind obj
                        app.renderView "#person_pane", paneview
                        
                    app.renderView "#person_list", listview

    return { "Demo": Demo }