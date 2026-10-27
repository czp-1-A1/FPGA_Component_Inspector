///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2011-2021 Anlogic, Inc.
// All Right Reserved.
///////////////////////////////////////////////////////////////////////////////
//
//
//   Vendor : Anlogic
//   Version : 0.1
//   Description : Anlogic Functional Simulation Library Component
//            
//   Filename : glbl.v
//   Timestamp : Mon Nov  4 14:20:41 CST 2013
//
///////////////////////////////////////////////////////////////////////////////
//
// Revision:
//    11/04/13 - Initial version.
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module glbl();
reg done_gwe, gsr, gsrn;
reg usr_gsrn_en;
initial
 begin
  done_gwe=0;
  gsr=1;
  gsrn=0;
  usr_gsrn_en=0;
#10;
  done_gwe=1;
  //gsr=0;
  //gsrn=1;
end

always @(*)
begin
  if (!usr_gsrn_en) begin
    #10 gsr <= 0;
    #10 gsrn <= 1;
  end
end

endmodule    

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
