import descanso
from models import Person, Pet
from addressbook.models import Contact

api = descanso.api()

api.register(Person)
api.register(Pet)
api.register(Contact)

urlpatterns = api.urlpatterns()