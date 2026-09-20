from abc import ABC, abstractmethod

class BaseHandler(ABC):
    @abstractmethod
    def handle(self, payload: dict) -> None:
        pass

class UserHandler(BaseHandler):
    # Bug 1: Mutable default argument (data=[])
    # Bug 2: Parameter shadows built-in function 'id'
    # Bug 3: Fails to implement abstract method 'handle' from BaseHandler
    def save_user(self, user_data=[], id=None):
        return {"id": id, "data": user_data}

if __name__ == "__main__":
    handler = UserHandler()  # <--- Triggers instantiation
    