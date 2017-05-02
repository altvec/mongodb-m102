print("Waiting for initialization...")
sleep(500)

rs.initiate(
  {
    _id: "confsrvs",
    configsvr: true,
    members: [
      { _id: 0, host: "delorean.local:26050" },
      { _id: 1, host: "delorean.local:26051" },
      { _id: 2, host: "delorean.local:26052" }
    ]
  }
);
exit();
