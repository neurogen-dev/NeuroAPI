from .          import models
from .Provider  import BaseProvider
from .typing    import Any, CreateResult, Union

logging = True

class ChatCompletion:
    @staticmethod
    def create(
        model    : Union[models.Model, str],
        messages : list[dict[str, str]],
        provider : Union[type[BaseProvider], None] = None,
        stream   : bool                            = False,
        auth     : Union[str, None]                = None, **kwargs: Any) -> Union[CreateResult, str]:
        
        if isinstance(model, str):
            try:
                model = models.ModelUtils.convert[model]
            except KeyError:
                raise Exception(f'The model: {model} does not exist')

        provider = model.best_provider if provider == None else provider

        if not provider.working:
            raise Exception(f'{provider.__name__} is not working')

        if provider.needs_auth and not auth:
            raise Exception(
                f'ValueError: {provider.__name__} requires authentication (use auth=\'cookie or token or jwt ...\' param)')
            
        if provider.needs_auth:
            kwargs['auth'] = auth

        if logging:
            print(f'Using {provider.__name__} provider')

        result = provider.create_completion(model.name, messages, stream, **kwargs)
        return result if stream else ''.join(result)
    
class Completion:
    @staticmethod
    def create(
        model    : Union[models.Model, str],
        prompt   : str,
        provider : Union[type[BaseProvider], None] = None,
        auth     : Union[str, None]                = None, **kwargs: Any) -> str:

        if isinstance(model, str):
            try:
                model = models.ModelUtils.convert[model]
            except KeyError:
                raise Exception(f'The model: {model} does not exist')

        provider = model.best_provider if provider == None else provider

        if not provider.working:
            raise Exception(f'{provider.__name__} is not working')

        if provider.needs_auth and not auth:
            raise Exception(
                f'ValueError: {provider.__name__} requires authentication (use auth=\'cookie or token or jwt ...\' param)')

        if provider.needs_auth:
            kwargs['auth'] = auth

        if logging:
            print(f'Using {provider.__name__} provider')

        result = provider.create_completion(model.name, prompt, **kwargs)
        return ''.join(result)