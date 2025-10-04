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
        private int remainingLoIds = 0;
        private readonly object sequenceLock = new object();

        public int GetNextSequenceValue(CatalogDBContext db)
        {
            lock (sequenceLock)
            {
                if (remainingLoIds == 0)
                {
                    // EF Core way to execute raw SQL
                    var rawQuery = db.Database.SqlQueryRaw<long>("SELECT NEXT VALUE FOR catalog_hilo;");
                    sequenceId = (int)rawQuery.Single();
                    remainingLoIds = HiLoIncrement - 1;
                    return sequenceId;
                }
                else
                {
                    remainingLoIds--;
                    return ++sequenceId;
                }
            }
        }
    }
}