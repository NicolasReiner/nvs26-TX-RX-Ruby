# TX/RX in Ruby
1. Run receiver using: 

```
ruby ./RX.ru
```

2. Send data using: 

```
ruby ./TX.ru
```


## Specification

```
FirstPacket SeqNr0 = {
    TransmissionId(16),
    SeqNr(32),
    MaxSeqNr(32),
    Filename(8...2048)
}
```

```
Packet SeqNr1 = {
    TransmissionId(16),
    SeqNr(32),
    Data(..)
}
```

```
LastPacket SeqNr1 = {
    TransmissionId(16),
    SeqNr(32),
    MD5(128)
}
```