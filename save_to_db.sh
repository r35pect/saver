#!/bin/sh

SHARED_DIR='/home/saver/shared'

# We need a copy of current-federal so we download a copy of just
# that.  We need the raw file, and domain-scan/gather modifies the
# fields in the CSV, so we'll use wget here.
mkdir -p $SHARED_DIR/artifacts/
wget https://raw.githubusercontent.com/GSA/data/master/dotgov-domains/current-federal.csv \
     -O current-federal.csv
mv current-federal.csv $SHARED_DIR/artifacts/current-federal-original.csv

echo 'Waiting for scanner'
while [ "$(redis-cli -h orchestrator_redis_1 get scanning_complete)" != "true" ]
do
    sleep 5
done
echo "Scanner finished"

# No longer needed
redis-cli -h orchestrator_redis_1 del scanning_complete

# Process scan results and import them to the database
echo 'Processing results...'
./pshtt_csv2mongo.py
rm $SHARED_DIR/artifacts/unique-agencies.csv
rm $SHARED_DIR/artifacts/clean-current-federal.csv
./trustymail_csv2mongo.py
rm $SHARED_DIR/artifacts/unique-agencies.csv
rm $SHARED_DIR/artifacts/clean-current-federal.csv
./sslyze_csv2mongo.py
rm $SHARED_DIR/artifacts/unique-agencies.csv
rm $SHARED_DIR/artifacts/clean-current-federal.csv

# Clean up
echo 'Archiving results...'
mkdir -p $SHARED_DIR/archive/
cd $SHARED_DIR
TODAY=$(date +'%Y-%m-%d')
mv artifacts artifacts_$TODAY
tar -czf $SHARED_DIR/archive/artifacts_$TODAY.tar.gz artifacts_$TODAY/

# Clean up
echo 'Cleaning up'
rm -rf artifacts_$TODAY

# Let redis know we're done
redis-cli -h orchestrator_redis_1 set saving_complete true