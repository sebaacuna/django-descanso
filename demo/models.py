from django.db import models

# Create your models here.

class Model(models.Model):
	# Allow customization for base behavior here
	
	class Meta:
		abstract = True

# Model persons involved and openings available

class Person(Model):
	name = 			models.CharField(max_length=100)
	surname = 		models.CharField(max_length=100)
	email = 		models.EmailField()
	date_of_birth = models.DateField(blank=True, null=True)
	address =		models.TextField(blank=True)
	
	def __unicode__(self):
		return "%s %s" % (self.name, self.surname)

class Pet(Model):
	name = 			models.CharField(max_length=100)
	master =        models.ForeignKey(Person)

	def __unicode__(self):
		return "%s %s" % (self.name)
