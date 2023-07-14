import sys
from . import Provider
from g4f.models import Model, ModelUtils


class ChatCompletion:
    @staticmethod
    def create(model: Model.model or str, messages: list, provider: Provider.Provider = None, stream: bool = False, auth: str = False, **kwargs):
        kwargs['auth'] = auth

        if isinstance(model, str):
            try:
                model = ModelUtils.convert[model]
            except KeyError:
                raise Exception(f'The model: {model} does not exist')

        engines = model.best_providers if not provider else [provider]

        for engine in engines:
            if engine.needs_auth and not auth:
                print(
                    f'ValueError: {engine.__name__} requires authentication (use auth="cookie or token or jwt ..." param)', file=sys.stderr)
                continue

            if not engine.supports_stream and stream == True:
                print(
                    f"ValueError: {engine.__name__} does not support 'stream' argument", file=sys.stderr)
                continue

            print(f'Using {engine.__name__} provider')

            # Try to interact with the chosen engine. If an error occurs, a new engine is selected
            try:
                response = engine._create_completion(model.name, messages, stream, **kwargs)
                return (response if stream else ''.join(response))
            except (ValueError, KeyError, Exception) as e:  # Handle both ValueError, KeyError and Exception
                print("Error with engine: ", e)

        print("All provider attempts have failed. Exiting...")
        sys.exit(1)


