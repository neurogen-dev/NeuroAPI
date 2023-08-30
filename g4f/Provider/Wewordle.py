import json, random, string, time

from aiohttp import ClientSession
from ..typing import Any, CreateResult
from .base_provider import AsyncProvider, format_prompt

class Wewordle(AsyncProvider):
    url = "https://wewordle.org/"
    working = True
    supports_stream = True
    supports_gpt_35_turbo = True
    supports_stream = True

    @classmethod
    async def create_async(
        cls,
        model: str,
        messages: dict[str, str],
        **kwargs: Any,
    ) -> CreateResult:

        # Randomize user id and app id
        _user_id = "".join(random.choices(f"{string.ascii_lowercase}{string.digits}", k=16))
        _app_id = "".join(random.choices(f"{string.ascii_lowercase}{string.digits}", k=31))
        
        # Make the current date in UTC format
        _request_date = time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())

        headers = {
            "accept"        : "*/*",
            "pragma"        : "no-cache",
            "Content-Type"  : "application/json",
            "Connection"    : "keep-alive"
            # user agent android client
            # 'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 10; SM-G975F Build/QP1A.190711.020)',
        }

        data: dict[str, Any] = {
            "user"      : _user_id,
            "messages"  : messages,
            "subscriber" : {
                "originalPurchaseDate"          : None,
                "originalApplicationVersion"    : None,
                "allPurchaseDatesMillis"        : {},
                "entitlements"                  : {"active": {}, "all": {}},
                "allPurchaseDates"              : {},
                "allExpirationDatesMillis"      : {},
                "allExpirationDates"            : {},
                "originalAppUserId"             : f"$RCAnonymousID:{_app_id}",
                "latestExpirationDate"          : None,
                "requestDate"                   : _request_date,
                "latestExpirationDateMillis"    : None,
                "nonSubscriptionTransactions"   : [],
                "originalPurchaseDateMillis"    : None,
                "managementURL"                 : None,
                "allPurchasedProductIdentifiers": [],
                "firstSeen"                     : _request_date,
                "activeSubscriptions"           : [],
            }
        }

        # Use aiohttp for asynchronous HTTP requests
        async with ClientSession() as session:
            async with session.post(f"{cls.url}gptapi/v1/android/turbo", headers=headers, json=data) as response:
                _json = await response.json()
                if "message" in _json:
                    return _json["message"]["content"]  # use return instead of yield
                    
                response.raise_for_status()  # raise exception if the request failed
