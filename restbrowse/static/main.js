define(['cs!restbrowse'], function(restbrowse) { 

    var app = new restbrowse.App();
    app.run();
    
    return { app: app };
});