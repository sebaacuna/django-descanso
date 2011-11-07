import descanso
from models import Person, Pet

api = descanso.api()

api.register(Person)
api.register(Pet)

urlpatterns = api.urlpatterns()