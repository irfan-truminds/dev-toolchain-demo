import pytest
from user import get_user


@pytest.mark.fast
def test_get_user(   ):
    assert get_user("1")
