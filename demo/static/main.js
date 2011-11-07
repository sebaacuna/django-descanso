define(['cs!demo'], function(demo) { 

    var app = new demo.Demo();
    app.run();
    
    return { app: app };
});