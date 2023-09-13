import random, string
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent.parent))

from g4f import BaseProvider, models, Provider


def main():
    providers = get_providers()
    results: list[list[str | bool]] = []

    for _provider in providers:
        print("start", _provider.__name__)
        actual_working = judge(_provider)
        expected_working = _provider.working
        match = actual_working == expected_working

        results.append([_provider.__name__, expected_working, actual_working, match])

    print("failed provider list")
    for result in results:
        if not result[3]:
            print(result)


def get_providers() -> list[type[BaseProvider]]:
    provider_names = dir(Provider)
    ignore_names = [
        "base_provider",
        "BaseProvider",
    ]
    provider_names = [
        provider_name
        for provider_name in provider_names
        if not provider_name.startswith("__") and provider_name not in ignore_names
    ]
    return [getattr(Provider, provider_name) for provider_name in provider_names]


def create_response(_provider: type[BaseProvider], _str: str) -> str:
    model = (
        models.gpt_35_turbo.name
        if _provider is not Provider.H2o
        else models.falcon_7b.name
    )
    response = _provider.create_completion(
        model=model,
        messages=[{"role": "user", "content": f"just output \"{_str}\""}],
        stream=False,
    )
    return "".join(response)


def judge(_provider: type[BaseProvider]) -> bool:
    if _provider.needs_auth:
        return _provider.working

    try:
        _str = "".join(random.choices(string.ascii_letters + string.digits, k=4))
        response = create_response(_provider, _str)
        assert type(response) is str
        return len(response) > 1 and _str in response
    except Exception as e:
        print(f"{_provider.__name__}: {str(e)}")
        return False


if __name__ == "__main__":
    main()
