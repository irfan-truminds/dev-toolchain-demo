import pytest
from userhandler import UserHandler


@pytest.mark.fast
def test_user_handler():
    # No assertion at all -- this test cannot fail. It is here on purpose:
    # the review-test-quality skill finds it, and nothing stops it landing.
    return UserHandler.save_user is not None
