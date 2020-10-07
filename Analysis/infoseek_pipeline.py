@schema
class BehaviorFiles(dj.Manual):
    definition = """
    # all behavior files in a foler
    fileID : smallint auto_increment
    filename : varchar(127)
    ---
    mouse : varchar(10)
    protocol : varchar(127)
    date : date
    time :time
    """