from piston.resource import Resource
import piston.handler
from django.core.urlresolvers import reverse
from django.conf.urls.defaults import *

class api:    

    def __init__(self):
        self.models = []
        self.meta_urlpatterns = patterns('',
            url(r'^_resources/?$', Resource(self.meta_handler()), kwargs={'emitter_format': 'json'}, name="resources-view" ),
        )
        self.registered_urlpatterns = []
        
    def urlpatterns(self):
        return self.meta_urlpatterns + self.registered_urlpatterns

    def register(self, model_cls):
        self.models.append(model_cls)
        handler_cls = self.make_handler(model_cls)
        res = Resource(handler_cls)
        rn = self.resource_name(model_cls)
        self.registered_urlpatterns += patterns('', 
            url(r'^%s/(?P<id>[^/]+)' % rn, res, kwargs={'emitter_format': 'json'}, name="%s-view" % rn ),
            url(r'^%s/?' % rn, res, kwargs={'emitter_format': 'json'}, name="%s-list" % rn ),
        )
    
    @staticmethod
    def resource_name(model_cls):
        return model_cls.__name__.lower()
    
    @staticmethod
    def make_handler(model_cls):
        class DescansoHandler(piston.handler.BaseHandler):
            #Note: Default behavior from Piston is to exclude ids, we're cancelling that here
            exclude = ('_original_pk', '_state', '_entity_exists' )
            model = model_cls
            

            def __init__(self):
                piston.handler.BaseHandler.__init__(self)

            @staticmethod
            def resource_uri(data):
                return ( "%s-view" % api.resource_name(data.__class__), [data.id] )

        DescansoHandler.__name__ = model_cls.__name__ + "Handler"
        return DescansoHandler
        
    def meta_handler(self):
        myapi = self
        class MetaHandler(piston.handler.BaseHandler):
            allowed_methods = ('GET')

            def read(self, request, *args, **kwargs):
                return [ { 
                        'name' : api.resource_name(m), 
                        'url': reverse( '%s-list' % api.resource_name(m) ),
                        'fields': [ { 
                            'name' : f.attname,
                            'choices' : dict(f.choices),
                            'type' : f.__class__.__name__,
                            'verbose_name' : f.verbose_name.capitalize(),
                         } for f in m._meta.fields ],

                    } for m in myapi.models ]
        return MetaHandler

