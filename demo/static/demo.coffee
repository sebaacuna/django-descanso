define ["jquery", "cs!descanso"], ($, descanso) ->
    class Demo extends descanso.App        
        
        constructor: ->
            super    
            @api_url = "/api"
            @name = "demo"

        run: ->
            @loadResources (app)->
                app.resources.person.get 1, (obj) ->
                    view = new descanso.ResourcePaneView(app.resources.person)
                    view.bind(obj)
                    app.renderView app.name, view

    return { "Demo": Demo }