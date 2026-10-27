//------------------------------------------------------------------------------
//  Copyright (c) 2011-2024 Anlogic, Inc.
//  All Right Reserved.
//------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////
//
//  Vendor      : Anlogic
//  Version     : 0.8
//  Description : Anlogic Functional Simulation Model for LOGIC IP
//                PH1P_LOGIC_HR_ISERDES
//                PH1P_LOGIC_HR_OSERDES
//                PH1P_LOGIC_IDDR
//                PH1P_LOGIC_IDDRx2
//                PH1P_LOGIC_ODDR
//                PH1P_LOGIC_ODDRx2
//  Filename    : ph1p_logic_hrio.v
//
////////////////////////////////////////////////////////////////////////////////
//
//  Revision    :
//  2024-10-15 - 0.8 - XT.XUE- Add PH1P_LOGIC_HR_IDDR PH1P_LOGIC_HR_IDDRx2 PH1P_LOGIC_HR_ODDR PH1P_LOGIC_HR_ODDRx2
//  2024-04-24 - 0.7 - XT.XUE- Delete device parameter
//  2024-03-21 - 0.6 - XT.XUE- Add PH1X100 and PH1S35 device
//  2024-01-02 - 0.5 - XT.XUE- Merge logic primitive of three devices
//  2023-09-22 - 0.41- XT.XUE- Update the value of ODLYSRC for ISERDES
//  2023-08-25 - 0.4 - XT.XUE- Update the pre value of ODLYSRC and IDLYSRC
//  2023-06-28 - 0.31- XT.XUE- Update the available value of INDEL and OUTDEL
//  2023-06-27 - 0.3 - XT.XUE- Update the primitive name
//  2023-05-31 - 0.2 - XT.XUE- Del ts port in pad_inst 
//  2023-03-08 - 0.1 - SH.XU - Initial version
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1 ps / 1 ps
module PH1P_LOGIC_HR_ISERDES
(
  sclk,
  pclk,
  rst,
  idata,
  odata
);

input         sclk;       //  [Template:Clock input of sclk.]
input         pclk;       //  [Template:Clock input of pclk.]
input         rst;        //  [Template:Reset signal,high active.]
input         idata;      //  [Template:Serial data input.]
output [9:0]  odata;      //  [Template:Parallel data output.]

parameter IDDRMODE  = "DDRX1";       // "DDRX1", "DDRX1_PIPE", "DDRX2", "DDRX3P5", "DDRX4", "DDRX5".[Template:IDDR mode select.]
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
nrl6BphjuGpP5hK/wsqRj3cdngsUzOhco1qL2p6llVC3H1AyFE/WeYqA/ABeK19D
lMMu3E8C9MQZkm/gTgKVXEbdmGbng02ACiu4IF5gZhTKZ+u8HAJajonBq/KfmW+N
VB8183hddi1X2Z2oUVNZaUoRPo5N0rO9R3rACzlPYK0=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
WfL+CZifQ48DA4zQNlke66HwInOcW9rQC16fWDnUPKGSrREqk3uCWgAFgzEBrWDF
KM1aWCCuSpG2JCnNZEoStU5QRoILe96XSDg82AlthbUPbO6zw1YHa0yhK7y32VcP
iRtrI8mIqmWCtCRiwkLCCBDGE5LIV2WF0+rNvEpveI8=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
MPunGdy2Wm+m1C4z8MSn15B+VrWVAFD5xURtyl5dmYaFGVBzOFDDNxNayoKhGBem
YCmTNJmbEkpBjHy49UqF3s399YW/uBRZxkokKVv7LsiwfukWRw0qUr562wUJ2Bk/
eIEHPVlmperEP9dCarJyyS0Khntbn2C8P8nC95oX586MP9jaQGbqIouarRIdo08e
Nkg24N9WlDxjcDi3EsrZzYetLeqvrU1blqM8eBEJjFY9IPoimxjDNt+Evv4mGZ4J
N0uiqHhbnfUTUNBpUYPL97Zjqx9b6vkUX1YYrbLK0TSWAHpNH7026gCieAzO1deH
6ccXmT19/Z7BksH4Wsy7/w==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
c7nFY+xp0jl24/Ie6R7utelUcPWNjHq7/QB9inRzg02LCI3KjStAxZHxEFprBp2X
5CsMCfRUQua5lLMGYOJBkbKFGBBnjJbc5kHanGEd/POqB3bWPMm/EP5a8Ybun2AT
6mFUblBVOYv3Wf0hnde1u7McEgV69GnUfVVETLkUYSY=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
d5CKGl7wO13A5PibCfTf3ep3lP5VfdAdUTDUcgVrnbdq3HE123UABssVyTW8neXV
7n7PvkBduCPwMUAFBlUSHE3FJzRSNKRpVmlKwIoiXPv+OsFMBk1ZiIT3gmv9HQlR
Xq7r2g+xpUwEp7Mfbm8cRm8mYpNr1l/ZfYqrPbRN61Go2VW2gs5O6RDqyasrBBJK
+RW8Ej004e9pAwUzvjU0BCaWyBpqin+JE9lnRL2lBpLmx1o/bsiPGYHHkqy6sDg/
McfRfZ+Ud+Ioe7LYD0bv1tQw0d4W9+1UYe45agVdTsY5CN9YPZXO6a7PrRc+SnRY
JeMGaxM6TfaN+qFFxMcvVA==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
dwBsRjJ6DhFEOG8co2OsFVRFXaB2dhsnKK8Piu9lfMMIefp2eBhs/A7+MFQ2Azz7
vpMmRPASr8/I+FgcPhaXWtKboFZioF28WjiGQe910xqPMknpXhFvlWiCWiOaKMPg
nFVPWfo/OZ+O82g+CmTIANagL8guXsOCHq2SFhVoA9muNGO//+IEzHoRLOcRW+O/
sgBXeMnZhnKyw83FilThvwPYsuuR1Dpd3rheAufAZf09s/Ipa1rzwlmN5M2zooH+
HAtMRLmdrHyq2QfqTWW48KYJ9Y77pfvLrFGo3yeOUvFFBDSTjmrOc1Z7oF7q1kM+
+oiHQkTcoWlfTYUy9MupWg==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 4080)
`pragma protect data_block
x87ehZRDvIs5+PLPSI8s7JRpvCcGeJj4Lq84nhpxllwQxL0xU4VMXRI0fD8KG47Z
rBFlGiTR3zIP+VxJBynmU1HhprHJkIJYSudcLFUVJLP0dSrSLrULGOulUPXmHIOn
DCtmglxCgQXYoc/eCjicp3kMRMLYNzVdBk2mNko32b1pSqH72f/metky/zvBj4cf
Ta+c5J3nvQKAUA3dYGouEiOI/YC8Su9+10Cxmf4ocdjLDoti10Phto4oQQhRpA3r
SL/RjepRF2+8VAotFhEx1xtvlm88vquZMacGh9lHdMrEIyFfbVSzO92SwtyAD+TJ
R2lkkmKFBbCdqYI1O4yTgXrHQgiMmw5kyfCIrB7LR+PFK/01wMi7qpzFzDexWb1N
p9s7LVYQQXKy6+aYHw6DU9XM6OhDm3t5I2ZhVRWW/1kJdpWlNiw+MC9Z6zLhMCrj
GOwpyq9Q9DA0JZ0T5IRNyy8scJcTH3E0mGOIOdplEtW2bEbbgQMmQvoEz2xEhjc3
Zmzn/rbvQHYHR2vjnaEnQyKNNPSXEw0W8QRDyLzdXF+o5mUOwghZFgqH7vp+iuL7
qMh0aZ1+3JkJ/6dU0yiomgVyaFcObzFp9r7PfPqwRfBghUZtffl3/enNpP22vOWg
yL7MyqiEfVIFTn8jGQL+yVpcliFJPIHBwPF9R8O8d9ueLbWvTRkXZh8P4UbzEqhj
ClYFa898MKuGvBq9Nrz5IRB8mlab7OVBf03snt6ApbXSF0M8k4m3lj1fAvhOq8nN
6hKYaTg6XfvbZQoNih7kYaQmMHR5cClut5BpaLYhiAm3U2Nm0Ki34nnDuWu/ZBze
gXD1TAL3I0AoGawTwuBXfhEJSTe+hR84J39RBMhEOUrd71fehOoyWrsgWJyU3DGw
4BhqlFL7eoBlQytY8bYOd7ynBAN7viSRLbMcjWouV4bD8drZ4bRZjwR2djllFDZA
tQWdQ1J+G0VP0FbLZ41Ls1UvSxW7eaAwayOG+z8xNUoVxQljPrpsUPHZGeWA5avG
hzWj4MAnNmWbIquIAurMytYFlNC+fUfrucJbcjLXJvSe3LsBY0zzKg5jhIwWhKQt
VDtOLVnPfxUjnkBors2FXmWw/DAtz9Nqqb+1AUwOZkvLYCdnprIBkFc8OvLQJYvf
3liZzWqiuFRxazn0GHz7qNSornamWXaxyDNT9rQBgz8XPHAqL7/WSRRVuoa9Oshr
xY4olDtlWZC/R+gxx5tpXPoHmKI2AdKltS+LZakgoffjS/5aT1a8i7Hty4Aw1o1U
Ays6RQ/AKADey0oikwbMzpXGULAp0IfXUSPqkXxmFmpmLa9oIIxJeDre2nc2rAlS
R0+Rbl54WQD4esjXNhp/58txDGXYQW/sjVw6Hl8rHS6oLsuTWSXQuxeZJ7QziHd9
BYXgmJCeY6sccCPr0RUXQEgANYWCCrRmFrJSMMC4HUbFixjipl+3iS/8YmFNQE9R
czjxgxh9ZWvPNzySMYfF8afeZGUbze5Fgrzy66ccIHZyK/cg9kP4CaWIh0qHg8MA
f40zXHd2wNJKvVY+Pm2GldyrUCXn3Qk/AQAR+uiUffWmiOy0w2RcsgfShhXVdXtQ
y1UFve3b/2tp/vNP3YzUfBDhHbkGMRimVcnlUnGGlowq0TK2E1DolI7wGKDYFZLV
YZ/VHR2JO3S9q45ze8BtxdrRCxmsx/bvOGtB6mU1aUPEG94zYF0Q8LhKvDEvQcSI
KLPHayoejHHfqMGq9TWYh1qJQZhrpuHAb8qAcTQRESdT5Lr8m3TIAeZEr6MNVkxo
28YCDa2nVyBSVvb+yyNGTyaCpJ+sCMekqUuUY9VHnRxcWrlREO+yfRkpAToNa4pP
uMVhhVldJMuwCpmb/fob+Naz497qrlSxTL5lzGxClTQV06zOJqgj1cA3PX9TcsK1
upDZTpOye/YxsO3YhppqrxafYsXVkGgbKRlnSOkAI5XJsUeJmffDWGmE2mvFE9Vl
0IP8uFZ/8fyX8WX74/gcYcdYVYJBQ2hI64Xn/ayjqLKeq1KjyE7QkJyOGU9db5O5
nN2fS3r5HVxGT8ttRzjwX/dPNwGH4GYbApK7J1AaPhl0jpVMKb26TrT/uZvKcl4v
A5/LljipCWEY7qI29fRHqXgQOxIQ9Da6zVMS+7v0XmtLx2PPWIzkdyGd51TKsJo8
/sfdNKwWq1GSVAmUfpcOG8pZqQqX4lDYIlC0DgLqlVc6AJdJyQQyeja4CN3WpXsA
9GNbm5wQ5K1SIM1hVHHojAU828mTBm5D5GzZ61vgN2/GNdmqDerJL9u/W3B1MbWV
1sNUZjUfmmBfC4Wib3T+aCldIYpy1HEzYELk2PczJNT+IPHX1G6zkigJ68tIUW7m
Xl7XQ0sztwqyqbZ5djlA4RvAKhxNXSvIPRdvqS34cYop/6y+Ov2wi6DzQOjEgbnZ
CUC4INMsoQ/xJUJfk/jchSMazh4GQnBn5LC3+Fb7RqApzKY6BBw0PIdMhukFNRMP
0pj3iL3+O+Re05D41FR+a3KWhEcQVLa+6aM4521bFZdixyFIcCm2kWMZaBerGqZt
lwHuL/JNFYR2oFmsX4mYqnE6fAMosEfD1jHK8rTYmrXhjPn6E+lrNY6puEfGpQUG
uI9aoSKHKQ/wHQBBAdZgKFMkai1r9xBaef8bA17Oc+BfIcCHW+3lpXQbHsiyC2Ad
Gk2WflGi72HXRk4bjvg5tn4a2zAasj3Ea9JqI3kT5jCsEf+Mu4Y9bPJy4TEYdFPL
ybBvYl5d3zVvoDJyHEYKqcsZI8niDSvI0caiQo35qe+G01mlLXKve3InEZFL2DhI
0NcWYuR9Loou+3e9xMFKM3Puc2dKt4RjpvH1ZIMFAxQvPZ/Yf4MhJHITO+bcXdXb
W6konSc240+KOwhSIo90pU/pPE6AMQpp5n/Uew+ZdQyX2NcLPw+GQO3aUhrjFmXf
KgZs9r6LthLDciMpZDeSu5JoSPuQen3INnhEsSwEpTtHTw/o0RC1fuVNmCx3nQzV
VzWsY0mg90R2y2TWJBTnhoMOsyoWNx68eK5kRQo+1c3EDXcX2tdhAyaxfb4Xqo5r
sOzjacK2uJ8DU+3ONwESb7dZ542XOAeDl2cVDffkyyl+eLw/4st0YLa8fckwLPdC
timeaX2MrNDxB3ON+6O86KJTwWUvzQzBPDW/opXXQP9BGyG1/jfVcOkjI4hXSg6f
77OmVpg2PMT3TcRy53YFAwCEtXRecGIra7pfNVpeYvziRxcro6Pzvchh/HtxQ+Ak
PL98OgjcG6aAYb6AxE95TZUK2qK3X3PC1Gw5IlgHNbjF10sbIqy0nYr3UIwW5VQH
oVSSDnrPnpud2AjyvPhJR/wcBCgA2YjCDzqjV2NLPchwae39mJU7FqMrRjNwWhXn
0M7csSMj+y0l3ZHVUF9OCUdllSHdSN7weaG7bybCN3gLV6hx+hP6GP34IZgEMUW6
zSfnV9Hv8yIumWTIKWsKjGX23jitx/r3xQ4n3ufl+u1fkQ5QKLLFI6K8b7D3stWj
QvVQR3YyoQpkrTauKpaQIIu4WWruMhsZxW+0uxjrdDmxDobzOu/exiH08FW4h2AY
gkfn4P+T/TXHogpyl2Z/hubJmHrgkSRmMbt0LHtL81v4JSRkNuHfgNF23brup9Wc
kgkd8p43/yeR+egt+yV2JfPUb8Jh+ClfXcXOVF47gAOQmdPKc2rwBi/7QpuxXbgn
+S6OpUCzWUcAfDWoc4ndlyl6iK62dAFZv6KQFtnEKb3nZTndfoe29/Vai9ZCyjar
W6emlRk2OtZA4MW867NDfv6VncC3/OB3sRleW9QipI7OKVf3HJRYMYA/MqxLfEGo
ozGSMA9rN4ESLvzUTMWYBjQOLwE3zGjk3GoOdjPYP1GIbiROAbXYqHfQReVK9kVz
j8mRsp+q0YVDmIAgRlpKi0KIsTUM10T3/umfg57xQAJofadjdlE8gdQpnTtkewvB
7S/pagYuwuXlJuiEj+4QZr7zy9ogp/pPwVfBa7Ry4yqlfQHcHz45jLQ6v1YnmerT
WeAkzHEIi/T2rlNsGgDDp9fAyAemhc7oUrKDnQBSjSOKqb1HKmDwh4y5rCelAc2U
hW4k6kud3kmFAyGH2PZ4i8tUX2ENh6NJzoTj50xbptTuYHysv63zl3Dy1y8IeGiG
ovKLv7hT94581LJoz6/zUFxS3EcB9wZudzzDmghSFNAX0E8q5G0jC1bpaL/Y/Jxq
JHT9GxsIjml8M6GdhHTaXpED6cTFMGuvi1Bp7I80j8O/CIQYRlrJCKn+GSArNnxs
CE31R6PM9RjIN3+wv/Cl0l4CNet0TefroCIJ7bZI43KTdnOA2VuwStvGtncwCd/U
ww94Hn08M44WLtNpsvxny0DlvasM9kSHlTgJ9NDw/I+yvQAu2tLl2snvqe6zybFq
ZhxBF6xGWna2I80hPBSBufTPqWnkmXxoLb6mYDZ6QK9BZlgwSnDle/KcKScQ5CZi
o33sTGAdB0OUaRO5XNrtA3WTeouJgzLeA1Cklz1o00f+gObqinoflq7sQIGXDm4b
vsMfXKYcgf52AVldYs4TkXwA4B/Kl7DAo4CP3lM7ho/21jujBGX1LuJL/CfEBXeR
cZ09u5skOx9IvnWKWFaKCrTPX0KV3mCxSyeQACNGhSi3NsOeX3KqSsYJLtWagF4C
cLyV8AR5o5Bhn4eGclSWtAxrg8BqutDAfvb7iPZ/abrp3wpADw7+C8Cz8dVxumLo
xEzZ6BYziW+aRO07V40tCe3tyyD0ez3rEp4RpU9EWSBGw+vyj926ag/19sM8I6H1
YwDm13p7kEBN4BJKAsMCISr+9rwLdmextmos5pcFcBcWJWloVZySzNF5JwKR0C9g
mmtHER0ETbDxdYEyg/FanZvLXwOEiidMznjFMoMmhSmGxoL101kyqmlwH8OuIWFN
uiKimjE3mcoA8qrkKBNkbXD1PT58wfGLQvmMJJGIu/7dGSK6kzp5QyPcFJKlRA+J
ds24Fh9/js5bQXh7pGmtDO9h20rSDEXJ1PCMulWGUChLvpAcH6TnPdiiz83SbGtb
TOJVpNlmgRrsQGwN5i1CFbVplx4aqbbBCq8kNsDDppk5aza94ijne5Q96USbBUQS
iWne6opD+OTmaxoXxRR++bczpGxr4ncISTTaP4F35NzSJZsKjiiN8yo2W43MNIWV
ePvX5qxcCyZJTcIhQb9T2MlETiwvBy1EgfLpMljyCCiLrND45QyN4SuMUAz5xIBC
QgiTm7qJL6i0T2t1CUR8jfLJsIsGNbBDvyf7bHN3qFs/CX51O03y/OsMbzdzlhNv
lr1S6geQXaDm2KRW65WQwD3oYYG9AyxmtUEAJgj5dfgbH8kywvcXeM1AWCN4eMSh
zJFd2+dFXXEjCea+mq2fpJ8pIWM9eA4MjbgZ5bzZ1iHbtS2I1+BVYsjYU0j/w+Ht
`pragma protect end_protected

endmodule

`timescale 1 ps / 1 ps
module PH1P_LOGIC_HR_OSERDES
(
  sclk,
  pclk,
  rst,
  idata,
  odata
);

input         sclk;
input         pclk;
input         rst;
input [9:0]   idata;
output        odata;

parameter ODDRMODE  = "DDRX1";       // "DDRX1", "DDRX2", "DDRX3P5", "DDRX4", "DDRX5". [Template:ODDR mode select.]
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
rYTDVLoNS+AX5d+OYTZfWHUWuQ7c9S4hqs4kuuelibBPXjxk8OaCUKxtEJYTWvKp
4NXLH8iFLRKbdWmoM6/fMo9oz1Ymdqo18K+UxvRexUX1N8NJUQVZBb6SjA6A2CTV
ieJXxAe9izsrevxNXyx2mg1UH5y1oEOMCTNW5/Djgkc=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
dn8CYtSDIJgMlQjI0yFweF1wF6TTso7zKw1xmYZEtgovD/q0KmbvORq86Ir8MOaO
484oiEKfC3vI5lpmlVNftzWvf4+u6YWAbSxvnVP7IURvBh+XyZ+mwBAG/tZNLv3p
9aXM91E9OweRddVdVjX16KRvYIojXxK8LfoYq9c3Hlc=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
QuFYM4Otm3XjwnzCzldIZSivcz6I3QNeD4EMJHFLEsv5rdcU9cvQHtvCzgN/b+1j
morRF3muQR80/QL456YbZ0Qe5btWIXw1tvAjO6cn9+CjN6dqtw4ruHQRyirFNfEw
n3pq0NNQLNL+a6ABwXbMxDyefg49K0VtFYTu31nLIEhO3C/gHDNcA29ABNP/t3Qw
/BFJCRtoUF/VhK1T80699WD5OOFzhrUBJZkP/xoYbtDpA/j1dxyxX0oCJJ5waXyF
XTKJa7VGI3WTUo6+ri48z35rVNM/Nqbeyh94YUkO6w+ob5tHCVRbeHL7sdbdYQYh
r6MUK5/E0h4z7MSgeHoPQQ==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
VVRbkxTs/tItdTIplZa4+yPh7IFM3lBxg9SHXaiiBXcdgpUe/+yuo/5IqtWhe3tX
aZLmrHNfr4aVEartoYUI8EurYST//wmf/CuBrFAP4q5OHy3xHI5sbDlVblhU1QXf
K/LCkNsWTpkXWHBeQkRYxsDqWn13dbLEmmWZlu4Fkkc=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
QOZJzhdDlaTkFP65Oi8YqLRFDUjM2u5CvJHLIExEuK2/Eo0lNgDtk+Uo4MgS/aTr
l3+ERmmQIYYsHYbEfc1PjNT1aecEWjOqNh9Nmw4Jevm2Mdy3cVY4+pSNYn524jXr
GSjrp9xj3teR3eDxHwePLtrs2zvxIrsLNaeKdATtEK9zfgWvkqvGSEZ4+mFyN842
QAbkL49Wz6BoNnMGD0fWn6B509zbDJPIRFYQ1a9jh9lQskOBAc3dqZmZkkHL17A4
QWaHU1iFwgH3yo4FYK5lGWCasPhRgWDR6WqxNb3oeyeL0fJehtUKFHcjD1r5qp3i
MFNQV5uSHddLGPvtslFDwg==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
PXKjkRPK7iASfJjJ4GRNzPNWNCTw8gr0TAQ4hwggq2tL/uADzknL9kJ/iwVp3vz8
AmmZtKNZI3KVAH+ATpeCiQFVqeXw6ud8s0kN5aUjTfEabZEA2iHa3kIdNPO8gXe5
w7U7dVMYaWFCAaWr4ps3NR5GfvLJ+sJ/TkG5mMY6wvX24JXnRPmoR/kQ/eaheN8h
DrQqi36Dp0c4OqWxq3ZPwfFrvYBUEmUQ21MZs4RfiIgV+hME67slhb3uO1qMb2ig
yU2F/CiK41Ymoyy0Ds0cIFKQDK0NVOZs3hqZy6bP2vsig00lnnq3ARPFfy9Kln0i
imls5ZeVT/znu7PhJ+C4mw==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 4048)
`pragma protect data_block
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
r5fgUYXeW6dRQn2Z3sHULQ==
`pragma protect end_protected
endmodule

`timescale 1 ps / 1 ps
module PH1P_LOGIC_IDDR
(
        q1,
        q0,
        clk,
        d,
        rst
);

output           q1;        //  [Template:1 bit negedge data output.]
output           q0;        //  [Template:1 bit posedge data output.]

input            clk;        //  [Template:Sampling clock.]
input            d;          //  [Template:DDR data entered on I/O.]
input            rst;        //  [Template:Reset signal,high active.]

parameter ASYNCRST      = "ENABLE";     //  "ENABLE", "DISABLE".  [Template:Asynchronous reset.]
parameter PIPEMODE      = "PIPED";      //  "PIPED", "NONE".  [Template:q0, q1 data alignment mode.]
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
PZWADSZ2RRX+j/wedDq5RXzTGsK/N+oT+eEho5vO3mSwiZUoCPqcmkfwU2UCiCEf
49N7mQcuqx5otXK+Wo8y97xBR/wuFCiObvPD8+qqmNlvNnvb5AP+akOgw+4exzT2
rGMEtBpW34z0sFxqYUi3ftNBpzgnyhPwokb8uhB6/2M=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
l8zT2JspootcRlq4d/IWKVAErJYHaChmY3UNFVj9n+xXwOZ0Uy40BERb0kb81y5D
Z0DCbN8rSsMeDjmT01gIXiZ0vL4ycgkBxgukJVR3Eto0EJtwfX+wVedcf8IXL4jE
uiLphd7hZXg5VTsGqDTHbmFJy8RT+Oq8xzLUAtgJmd8=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
Gegwa2VNO4X71Hkaz1zag/oKZzkAzYcrTYTu0ffMjosNlQPZJcsOD0UCtb7PT2YT
KNeYx5qnYRJK9m3Qtjaqq+QSaQhipf4XGSHt/3/L9SSUigq9eGu/212cQggEswCv
lzyCDX1JrnHaWY0Z/VFbWGABCW18zMC7MiP7RbmdK9wyeSYcTJccsovFKiCckB7q
8bN8qliZWm3coNYbIAK3uHwVkFMY7cF4Ve/WQeyYHSlbwdsWJSYwckKlT6JxH+2A
IEloSbfjxtoOCy5PufcSKGO52vSKzWEIamFPBTkPP+MhyHo3DomA2oQ8eKtGKmh3
yqoJPrBEGb8wbZbjFtKxEQ==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
WGodgfnwawprAa85J40ZaEmAzxmOQOy+6iywqL8O0dMx5JBChUOUGgaJ7tLa9E3E
NMxcoL+wi1CsmfYLX+d/aKjoa+q/J8M5NcBfiD8siTo8xSYL0ILlTgVr5j2PA6Ih
15OYKQgbu6C5mOZIZjhjm2LJnR/qAyg8ZPA0NLKw780=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
L5XvYJQJ+HwBP0QAHYTThPCWag8Jsqe62y4oCyZrm7rml+MbiRYK1V7FoyP5EvyE
kqfjYLX0DoSciuY3oxYx0d4SgAs0TYvvGmk8eufGdrR4WgNW957/kvDFJ7iRLoqM
4HlS2Qpt8gsllnfbGQvWEsTdn8MHCo1CuGuJJaewBKy9zeF/a9tBErcUkIypQoKE
N+Gc7yzxedpq8DsvfQPfvDJsmtv94x6f1e6TgX3PNbJ4D5EITwJy2eX+6eKhZqMu
KAiSKLYVy4qDDtUz8zsdYzw3hX7MZQXOEqXWPf42ATXdD8Eo5Qtopgov/2G4CRfD
0S/OpFOLkM4LFaxV+/V12w==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
qrpZV13LG+PzBHe6AZt2QDoh7c4p7so4NsSx4FjkTLslApZTpUaQg3s3HP5WW5/1
rdiHHiGyebQeYtZSys72ToDIfMkY/gpEmS8eD8Arai7YT3lSgO/3Hhmmi4VzUsUg
RL/nKfFjq7hdS6xwaHjPVGRopzT01LzSeDOTChMzpGXWuz+FZTh/x4dJKoeJki56
FqWhGkhte4KXq3bKO/JInZYQu3+62AcKKJAIgA4vVtvxqKqbLg9nDKJNVVnvta0j
ZHKNNex4pM1svwv/qNlbbAhgmiAnl0VzNx4FNdT9SAMX4rFQoE5uOtSC7AYkjDjE
25pvc9PBXwGGbBJyPOmgug==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 4464)
`pragma protect data_block
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
`pragma protect end_protected

endmodule

module PH1P_LOGIC_IDDRx2
(
        q3,
        q2,
        q1,
        q0,
        pclk,
        sclk,
        d,
        rst
);

output           q3;            //  [Template:The 3th bit of parallel output.]
output           q2;            //  [Template:The 2th bit of parallel output.]
output           q1;            //  [Template:The 1th bit of parallel output.]
output           q0;            //  [Template:The 0th bit of parallel output.]

input            pclk;          //  [Template:Clock input of 1/2 sclk.] 
input            sclk;          //  [Template:Clock input of 1/2 data rate.]
input            d;             //  [Template:Serial data input.]
input            rst;           //  [Template:Reset, high active.]

parameter ASYNCRST      = "ENABLE";     //  "ENABLE", "DISABLE".  [Template:Asynchronous reset.]
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
MtEmKoNsh36Vd6n72lmxQsI93YySWU48M1IMxrttBEDQX74A52e7LMpD5Wfvz9fC
rabtoJJBtIEQxGouCwGWtFkvbqtXdP6nzRd9PgLtn7D4hXaKyyW9nwLQxdqKBd3W
lIsnzDBrBe8sdDqNzM5fwRBXKWXMbAbZEmQBwbNHbko=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
ZL0GSy9q18drTZu/Zx/otBcs2bSxyWHDRROqikdskh0PI/GsP9QOQgzuJsRK6QQD
IWMjlE79ZnNptLFA4UsQnuGu9wzddb6Io+S8gD9LdxF+GikcBo8FsckUhF0+fslQ
kGxBVKDCBmwS+oOQ3hBRPoMynjTnkHTsWI2xRgGtZrY=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
EpiWx6cVAzgan6QaqHvZmUdo1DrPfM+UF39f/rXUWU0liUOZW1M8w7bAGQeJHmGm
wPNI7U14+VHNjoJMXWQj6Dh6jaVGHfFvPjKF0Y/0cMr0Hs51Ao3VKnL1X27yb9Pz
Xm45Cmr+edntIhqsyjgOj2V5/r6f2CLCjBuRjKVs2U3NMjd/fGZsGfCM3i7/CUIL
2EA/qWv4DiJC5oYAwWQRK+OlqpDYH8czkeSGsSlo1nAaqj2cIW5wecsH5dujgRnb
1oxe4el4zA+5ka9pbQYSLoC/Z1ooE5Vs3npMyp/+e2dlWhpzSVU/AVUo5TZG877z
sgD8fTXX0cg1e8zQ2S/DcA==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
M9wbR/+VmmGoZl/BEGQyIbnnPFEOABIKedg8Rbeki9Wgi9B6m97zM8dz2WHvs/Ut
jnKElEwgiTvMINYY8Q0an+0yXBsyP8UOsEtOxvxPJ3bO1av0Io6gJURw8meHFP6t
ouPDyKL78zgDzTu+kfJelmFMM6mx6M6Fy4mjGd/OH40=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
E34O8baiZGOn9I0Qfm+qTiWNhTvE9gR2dAU1KproJeMvmUoQOoDcs+OX5upY+8z6
0P3pVCl/FQnfUae+/5gqd7VxBVOBQZsWgP6sLaBpO45jpBOXxt41jOvlw5czCF9A
GOG1WMnxd8F3mX/iyeFYQwBsFEwh2zfqW5W1KslwTTMBJIhidqVKk5GdPb5jzZsG
oLdizYMITzswXu6wkI5zv+OhcL6xUoVWGM9w1dDPd9IZWRvGfB5Q4uJyJX9Qni6W
2KNHu1+LxCoU6hPV+pX8Q8kb4C2AER/gkePnwwly9MaFU4uXQlGRyvHnbtr2kEEM
pFAkTy9kDDy/N3/CZKkWyw==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
Li7bUhWg6nIaQqL/2QOfZ4z+8iEcqNHA07jAQmv7E1slWq9V3yfsa5Em/7cXdtKR
SzNe/eb/vClJZcW+QsOCB6HDP3USVtSz7O3yRSRfBcKsCNsIKZ0zQv5nOuHPRJeV
rdt+q3IiOhFWeaQ1Fb9pkwEeyJB0MDX3YP+/azVnpt8dmJUpEk1CGnOoyP7jisEk
H+/waHnSiBwd0SS/9DLdafnJh5QiJSqyrqCv4Oby+snaKvWBbsWQGEBpYPQc1rE9
icJg2Sbevhr5q4wG9ziuZEJWkm5tu4c3ayESqyCfR3HM00aJdtD2QjvThHpI5YZb
DUaAUgXlU/l8hpZWX9EeNQ==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 4080)
`pragma protect data_block
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
`pragma protect end_protected

endmodule

`timescale 1 ps / 1 ps
module PH1P_LOGIC_ODDR
(
        q,
        clk,
        d1,
        d0,
        rst
);
output           q;           //  [Template:1 bit DDR edge output data.]

input            clk;         //  [Template:Synchronous clock.]
input            d1;          //  [Template:1 bit negedge input data.]
input            d0;          //  [Template:1 bit posedge input data.]
input            rst;         //  [Template:Reset,high active.]

parameter ASYNCRST      = "ENABLE";     // "ENABLE", "DISABLE". [Template:Asynchronous reset enable.]
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
jk+DZUozbhP06T9gSEot+pJCuo+Gk1Y2SDY6pJGiY4gm801v16/Fhjro8ZZM7/mA
jdxGlIrc4/a4rj1/zlBO1FCJLb4ys128lznZtctzXywB7omnaelAvFyU2edjI7R0
HTYqsLIkYSKAkokNXCnG3Thhj8pOZMAq6weFfW/8guw=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
AMub46khKHUKNbnZd5ft/+USLtQzRg5s9gCqQENO12tjKxffSOoK+lL8XPc/NZ56
0WooRZUTKqAtYfE46NTNxn9XRDoLP0+sAajnsqw6LtsG0/G3iQsl6WH7/gMM0Xmo
+WTRtayT3/vih59FkmSWlqRaxvpLf6iHJgiLvLYUWDQ=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
BV7PQ1tIaksNZtNECrN0DS8hPK9Jxa6H8dCHk3AjiTsrUs/clGrELFPykqVN9QWy
Bi8zcAPT/dDVgMXYf4HSwUmy9pS1RM0vCX5zodpnX7RGMQZCEqu3Q0jcnOwjkddl
Kc+gG+2EIcfpKFl2M3Oi/lrw6BOqDDIcRGysHImR24Q4x2cbS26qBASTyNtwtr2f
Hj+rn9kdFwOtjtaYp5svfEkGtgEgWN7X9PYU6Yebc3K5mqIHXRlv3K3dQwqU4fbx
jJPprbNdqFl7YJ8TJEPXg2dAxMm77CsXqhp1RWS5zNZoMsBytJa3P4L8Y2crCVrJ
RfQMWVlP3yNroIvuodi5dA==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
axfVclVflQ/c3JSzFWU7CSQcCewOyNHhBx6esw6psrCoOZMe01gAROd4FfAQaCTX
8RLxEjaNW44arrhACYCLJZWzPecDSJXSdPW8tdP1QP1i7kCg9wYlqYYwk6B0JdAo
xix9q7nGo94R0ESNyTVt7kKl3z6FD3oWmb7qZt2/I0k=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
aC+5KenbwLYQDoDegW757FVpSinNIVax6nIKQLyURc3hso3ecvcUIflnOcKxj7kz
IsHGq6fxJodKHCM24KI74c6urEkWD3tPteFHxUi3lkIGGmUDusMCFew6jo+GkiwB
pZ0s9RfXdVWUILvISA5d7KBxs+nsOEs2YXvQIFMBW+G/ELlunZZzCt6PTibImo5z
8z1cg32RdB7Lkw2GUmVWmU/2C88NBDzcP9uD2qoUFR8hZJILLXo1JAvGutHX5osY
5OEskzhbJxzS3475LD5e2S1XJuOfgAMmZ5m90UiIv3hbgSChX7ZhP3lVmgVxU2Ae
3e06GQJG2qiwDNNEMao6ew==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
sIaVOGays7lGRXos5tOqbgzff1iKkS87MlqPxCFTYRZaZGJiq9NaVN8CiDlZIWMJ
49pXpBFj08FrayUyy0HXXz6747iIoL/C+mn2JmmhXk2vy36Kp0vTFoXC0T1pqwSJ
lycad4A8CkWg4IAsEel2f8Nw11smG64U4UNcyKVdeFob3otpz1Ie/NIaa9w9qX4c
4T5dxW7z3W60jFdsR1ycer6G4JnOlYXiFHLlqR6C8fiONAtSovh8qXghK2Nes8T1
+XaQllZWFBt+E3rktWPFty7DFPh0hkv8S64g/aZ2wcweyBiXOJcNduaiuYSV9D6G
vQYo8wCz1PFrUZsohS0GXg==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 4096)
`pragma protect data_block
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
WVUkHy0JDhhM4sG+yxrrKQ==
`pragma protect end_protected

endmodule

`timescale 1 ps / 1 ps
module PH1P_LOGIC_ODDRx2
(
        q,
        pclk,
        sclk,
        d3,
        d2,
        d1,
        d0,
        rst
);
output           q;                //  [Template:Serial data output from IO.]

input            pclk;             //  [Template:Clock input of 1/2 sclk.] 
input            sclk;             //  [Template:Clock input of 1/2 data rate.]
input            d3;               //  [Template:3th bit parallel data.]
input            d2;               //  [Template:2th bit parallel data.]
input            d1;               //  [Template:1th bit parallel data.]
input            d0;               //  [Template:0th bit parallel data.]
input            rst;              //  [Template:Reset,high active.]

parameter ASYNCRST      = "ENABLE";     // "ENABLE", "DISABLE". [Template:Asynchronous reset enable.]
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
v3GKn06Hm4Yhqar0maD467hU5MUhGenXMq40K+etz2F1RGdkL9X7ZqmnOIj92tjp
2zC4XNl7Z3naZftbigIFYRX15IaRI1u0y53LMzaSOjXbKKdGolthIStBI6Q+2pnM
4j4sNLvra2ysU4PIg0WzyeEjwrDHAnbiiz9iSnIS4xs=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
sZ674gLEyahuI3tA6lLV5opjImAs5w1cZP1SOzi43jE9fBFWabU5IkbG029Tbg0A
D2qZQS9q6AKQP0WM5iIVjAHjjsNU5QFruoLnctbvp8yjV5VpopgtXmm3L4/sdhLa
HBimFbbk6b2OXe35hUti4d6O3xrX+krO51gRkgFdcUk=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
Rg/tXYvT/MaUcz4geuhsu8rhd9M1FoysORgM3IOp+cQyrI2uMd5XHUzKlGwn24J6
hg69uXsY8s1LNQxNupIq5DR7JCisSGSaVT6Gzmcidijy5MzEvnTZM0YCDVJdkmWu
YEvtP+ZSor8muG144anSgrHxWG3pNvhMeqNAcbDiwVQsN0EfgFSxgvalU/K2AryA
FNC7IG563DLAxG1K5jbaRXj0hmSxVDq2P0e7lKo+VZVFCJvA4Rl6n4xK6AMj0Hfx
lvrBucDp9ssAScmnPYbKG45RVC9OsL6JL3CowOGhm2LmN2JkHG3wHDqYjE47khne
Pp9TksXB9zpF8WOO5YuVtA==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
VYS3DyjvCNUTG73vYoQMCmxKzWoFIG4jb7cnscpksonpssFMETbw61i60s3BbGT6
oz3K7xfpwIe6tZHsd/pEBobcecHcV8I8bJ2Cqpr1WimONvBoz+V85kd3Dcy/GZ1v
XeB/W4uUUTHMUW03qDuEpc+L9NjV/ZIZx1yNcc2YJkU=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
e14qYLBZxM+125LA2v7lGIlNxA8lFUDq7WIsQTNA3AsW0aMKUUOw08BFqJcJI3s4
yZsp8UdDbKkQ/JAk3SeiJ0ePzOSxPvB60vv8UrOvjolG/6FakNIMWD5vRujHRho3
Dupx9iZXxpe4q69n59Ib9UQPCHAXqUD7+S6vRDA57W0tLh8oIv57BjznJ45v9hVM
SAlgezFcbDijzsnxvZ7uAXPq6N3Kw7liINYIPGvLjdBeqBCY/hdnkPApA+8QUhFN
+TvnAx4wwIc6Dnd7zPlZx42V9Ao/IpNM+IW45umc/aQ38w9ZMWAYq6uCxK0TuCaN
OICOm2nmgfjGG67mQCHrtg==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
DgUhmZIIH8ZuDfT95H8h3m4/Qcb0A2HiTvVmtSApqoiMCP54nKkVRl9Olwk/+lbQ
Oy37mOllZLeX5HGADGIQCY4lB68gOGdIfU09/jWL3a864OfQWcr98RrtOOsD1SKE
VJFtxlrbS/wGtMccFERzTiK9XUbdqxultqZc0eqE9UR+E6YiMDRYg+MNuIu1HvgU
jfTeq2X7BrWx8eU/WyD2M4LU2odXhWsWCwnMEF6NtQwyeBu4gYxcgjF5uXAZRBEy
Cz967oDxP0wyRvSXex/jfhWpxcgnkEpys+iE0UsLw8xTud0QmkJTiyIwxQ8R420Y
RpRsGt+MLDaU0E1kBIi6gA==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 4096)
`pragma protect data_block
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
eVdF0OSvS6IbzK5w/LiWtw==
`pragma protect end_protected

endmodule

// End HDL models
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
su4MlKU8+402CR6LDS9cxwTZKAbsI23atz+mD9jtwCUG7eacE+xXQkUYzN0yJjpg
FFAj5jbDdCzvJvxmkkIGXG8s1C/fENg6HHyaaITD11bUqngugvF+okTDH7FAqFB5
YcKHb8Vlz1iGqKMJ3RZGyeFvWPNf6wusp0y+o8Zh3j4=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
f52n19Q4urMvPA1qKx/AvVPCfJ0yZuzrsm98WHnkcOQlG/glV16QDR7S37iyPxbK
qJ6Mq4qZS8TFMon9XwQ5mamrKQ2wYYqeX1G9oi3C8D/wETXUNLVWLbJGs57SByCP
eMsvjeZ4BAgumHa+5qZA/ByP+5ynklqMFAOXYRoArX4=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
pTJ+eXstmGdQcwTO/QGESBpnJ7eRVHKjZvnAOtjDi/AC7c0RzAGnWaRBPSm/UqND
2TpgsuvccOorAUHyIhor3qkv8jtWIr3y9W36nRj4JEO9ijXdvhJXpOQ0+vgo/Tbg
rr3+x9jIzDf4T7CUSpuIqsQW1Fdg7vweZ12PaKHSTU/JTvbSca8jO7tOPwV5KUg3
cutVLwqPAK7sCeAf72D1+eBArtDqZgGSht+D7UxxYrv8RmXUsCGbpO/j8F48U++U
rXTNWYNTJMq0w1/VpcESphLsb8b2TqhkoomVtTmG7YcunwKJpsKaKTl6l48EQvHD
J4DLqYP+wYbFrcnEyEewZg==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
ZvfzAf7PRkuRm6nsiXQV6BdDpJobl4DYrcQzc86UOyrt/gUme+6RKKiIUiggiGnx
YRvC9KUC4xQI12YYNCPT1rMkcbc3QFfoSbLaVElJDxrf9FahbvTuy/efU/5aIEsa
RBKnW012FMo3+OlUcoKdNOD5K11yix0Y1iIuP0s+xF8=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
Mq9t6Xrtikv4COKcSVZ3ZshBLHqoVAYuf0jbOug5+ExESnVQkpWhHqHpk9+wI2rg
3/9ZTT8FD4KJVL0+RRUB1UxCVUsCOqDa2+zg1V4Hk0m2ZEBH8Kw4rIT+Y3kBaDWz
wQ5YekxLURcV34ut6OmK7AT5k7UHM2gwt0NSqphPsF0gkGGM1AY8BdLS0T7r/L8j
vnB4ld5WCHGFeLa98WfUte5AiT0TK7XYVf6Dm3HRBziFq9H3oasVOyXvPXvw9BN5
MO37YZq2r2EzGnULbpbUJV9jmpFdgFxNajhKOs5fXSn/Ku/6KbpR6Ty+UKH4ZSUV
9w+dZZBBSQABuSqj0RoDcw==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
d2lnGYQDieLPRG+78shxbu3QjfNQDUwoe8TYcHXlDthRQgqRCTTGtfNi0HPFs/zh
iaCLIbHbkdc5jWR2W0IXvxJ/OqLBK765y+MvasdyxnAAjn9u4e6SvBpRvjnbUwZT
byEhK5VtRAygzKFgg10UP9kWEmgf3gY3uB3LsilDqkg1xW1LpMCZBW80SNkwpDGy
hTHkLC9pt1MR/BNZiEKy6X0p0nuDQXdBZW8GBg5Mx8SH7nQia/n/2czlE31680lJ
opneOj5gWawQHxg4GEd6YMiqYoPKwWTXH79KFfVFuge8OSevh1nylBWqUMnP89Hs
uDqv1GxFTlUVmR5hQ0ddKw==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 48)
`pragma protect data_block
x8CRoYDY1tGjhtOIgQ9QdhJG7AyClCYRNVYsYgZuuXzlxwgg9X7WDtYnFu8Fp13u
`pragma protect end_protected
