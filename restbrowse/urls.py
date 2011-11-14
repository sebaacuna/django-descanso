from django.conf.urls.defaults import *
from django.views.generic.simple import direct_to_template
from django.contrib import databrowse

urlpatterns = patterns('',
	( r'^$', direct_to_template, {'template': 'main.html'} ) )