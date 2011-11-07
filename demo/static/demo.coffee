define ["jquery", "cs!descanso"], ($, descanso) ->
    class Demo extends descanso.App        
        
        constructor: ->
            super    
            @api_url = "/api"
            @name = "demo"

        run: ->
            app = @
            @loadResources ()->
                app.formRender 'person', 1

    return { "Demo": Demo }