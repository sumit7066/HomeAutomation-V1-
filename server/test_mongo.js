const mongoose = require('mongoose');

const uri_direct = 'mongodb://ss7083024_db_user:ZLBNcrFOyaplLOuJ@ac-lwgkmdv-shard-00-00.gvifnsr.mongodb.net:27017,ac-lwgkmdv-shard-00-01.gvifnsr.mongodb.net:27017,ac-lwgkmdv-shard-00-02.gvifnsr.mongodb.net:27017/SmartHome?ssl=true&replicaSet=atlas-7caltw-shard-0&authSource=admin&retryWrites=true&w=majority&appName=Cluster0';

mongoose.connect(uri_direct, {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(() => {
  console.log('Connected via standard URI successfully!');
  process.exit(0);
}).catch(err => {
  console.error('Standard URI failed:', err.message);
  process.exit(1);
});
