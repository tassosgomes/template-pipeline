from fixture import render_template, soma


def test_soma():
    assert soma(2, 3) == 5


def test_render_template():
    assert render_template("1 + 1") == 2
