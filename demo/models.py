from django.db import models
from django.core.exceptions import ObjectDoesNotExist
from django.db.models.signals import pre_delete


# Create your models here.

class Model(models.Model):
    # Allow customization for base behavior here
    #deleted = models.BooleanField(default=False)
    
    def delete(self):
        self.delete_related()
        super(Model, self).delete()
        
    def delete_related(self):
        pass

    class Meta:
        abstract = True

# Model persons involved and openings available

class Person(Model):
    name =          models.CharField(max_length=100)
    surname =       models.CharField(max_length=100)
    email =         models.EmailField()
    date_of_birth = models.DateField(blank=True, null=True)
    address =       models.TextField(blank=True)

    def delete_related(self):
        self.pet_set.clear()
    
    def __unicode__(self):
        return "%s %s" % (self.name, self.surname)

class Pet(Model):
    name =          models.CharField(max_length=100)
    master =        models.ForeignKey(Person, default=None, on_delete=models.SET_NULL, blank=True, null=True)

    def __unicode__(self):
        return "%s" % (self.name)

def delete_related(sender, **kwargs):
    kwargs["instance"].delete_related()

pre_delete.connect(delete_related, sender=Person)

