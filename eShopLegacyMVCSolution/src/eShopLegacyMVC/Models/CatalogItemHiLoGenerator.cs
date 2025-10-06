using eShopLegacyMVC.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;

namespace eShopLegacyMVC.Models
{
    public class CatalogItemHiLoGenerator
    {
        private const int HiLoIncrement = 10;
        private int sequenceId = -1;
        private int remainningLoIds = 0;
        private object sequenceLock = new object();

        public int GetNextSequenceValue(CatalogDBContext db)
        {
            lock (sequenceLock)
            {
                if (remainningLoIds == 0)
                {
                    var sequenceId64 = db.Database.SqlQuery<long>($"SELECT NEXT VALUE FOR catalog_hilo;").ToList().Single();
                    sequenceId = (int)sequenceId64;
                    remainningLoIds = HiLoIncrement - 1;
                    return sequenceId;
                }
                else
                {
                    remainningLoIds--;
                    return ++sequenceId;
                }
            }
        }
    }
}