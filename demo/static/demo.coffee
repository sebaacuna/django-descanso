define ["jquery", "cs!descanso"], ($, descanso) ->
    class Demo extends descanso.App        
        
        constructor: ->
            super    
            @api_url = "/api"
            @name = "demo"

        run: ->
            @loadResources (app)->
                app.resources.person.list (obj) ->
                    view = new descanso.ResourceListView(app.resources.person)
                    view.bind(obj)
                    view.onSelect = (id) ->
                        app.resources.person.get id, (obj) ->
                            view = new descanso.ResourcePaneView(app.resources.person)
                            view.bind(obj)
                            app.renderView "#person_pane", view
                        
                    app.renderView "#person_list", view
                            
        newEntity: () ->
            view = new descanso.ResourcePaneView(app.resources.person)
            view.bind({})
            app.renderView app.name, view

    return { "Demo": Demo }