from invoke import task

@task
def gpg_check(c):
    c.run("gpg --decrypt tmp/example.aes")
