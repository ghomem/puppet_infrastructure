import datetime
from pp_auth import *

import OpenSSL
import base64
# because the 14.04 version of pyopenssl does NOT load public keys :(
# https://github.com/pyca/pyopenssl/pull/382
import rsa

# friendly names for pp_auth actions
ACTIONS = {
    'auth'     : 'login',
    'extauth'  : 'web login',
    'setpw'    : 'password change',
    'lock'     : 'lock',
    'unlock'   : 'unlock',
    'useradd'  : 'creation',
    'userdel'  : 'deletion',
    'expire'   : 'password expiration',
    'unexpire' : 'password unexpiration',
    'reset'    : 'password reset',
    'testemail': 'email testing',
    'inform'   : 'informing confirmation'
}


# wrapper function to send email easily
def reqhelp_email(email_from, email_to, subject, text):

    # Create a text/plain message
    # Using utf-8 here made accented inputs from the browser work
    msg = MIMEText(text, _charset='utf-8')

    # me == the sender's email address
    # you == the recipient's email address
    msg['Subject'] = subject
    msg['From'] = email_from
    msg['To'] = ",".join(email_to)
    msg_str = msg.as_string()

    # Send the message via our own SMTP server, but don't include the
    # envelope header.
    s = smtplib.SMTP('127.0.0.1')
    rcpts = email_to
    s.sendmail(email_from , email_to, msg_str)
    s.quit()


# specific function for notifications, uses friendly names
def notif_email(email_from, email_to, username, action, result, extra_msg=''):

    subject = 'Hashman ' + ACTIONS[action] + ' ' + result + ' for ' + username + ' at ' + datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    # we add the extra message that might come from caller
    text = subject + ' ' + extra_msg
    reqhelp_email(email_from, email_to, subject, text.encode('utf-8'))


# SSL digital signature
# uses pyOpenSSL expects utf8 and returns base64 encoded
def sign_OpenSSL(message, privkey, digest="sha512"):
    input_fp = open(privkey, 'r')
    PEM = input_fp.read()
    key = OpenSSL.crypto.load_privatekey(OpenSSL.crypto.FILETYPE_PEM, PEM)
    hash = OpenSSL.crypto.sign(key, message, digest)

    input_fp.close()
    return base64.b64encode(hash)


# verify SSL digital signature
# uses rsa, expects base64 encoded input, digest type is guessed automatically
def verify_OpenSSL(signature, message, pubkey):
    try:
        result = 'UNDEF'
        input_fp = open(pubkey, 'r')
        PEM = input_fp.read()
        key = rsa.PublicKey.load_pkcs1_openssl_pem(PEM)
        bin_sig = base64.b64decode(signature)
        if rsa.verify(message, bin_sig, key):
            result = 'OK'
        input_fp.close()
    except Exception as exception:
        result = 'NOK'

    return result
