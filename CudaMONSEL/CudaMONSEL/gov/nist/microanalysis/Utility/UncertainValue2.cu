#include "UncertainValue2.cuh"

#include <stdio.h>
#include <math.h>

#include "..\..\..\..\Amphibian\Hasher.cuh"

namespace UncertainValue2
{
   const char DEFAULT[] = "Default";
   int sDefIndex = 0;

   const long long serialVersionUID = 119495064970078787L;
   const int MAX_LEN = 11;
   bool doubleCmp(double& a, double& b)
   {
      return a == b;
   }

   UncertainValue2::UncertainValue2()
   {
   }

   UncertainValue2::UncertainValue2(double v, double dv) : mValue(v)
   {
      char tmpName[MAX_LEN];
      itoa(sDefIndex + 1, tmpName, MAX_LEN);
      assignComponent(tmpName, dv);
   }

   UncertainValue2::UncertainValue2(double v) : mValue(v)
   {
   }

   UncertainValue2::UncertainValue2(double v, char source[], double dv) : mValue(v)
   {
      assignComponent(source, dv);
   }

   UncertainValue2::UncertainValue2(double v, const ComponentMapT& sigmas) : mValue(v)
   {
      mSigmas = sigmas;
   }

   UncertainValue2::UncertainValue2(const UncertainValue2& other) : mValue(other.doubleValue())
   {
      if (&other == this) return;
      mSigmas = other.mSigmas;
   }

   UncertainValue2 ONE()
   {
      return UncertainValue2(1.0);
   }

   UncertainValue2 NaN()
   {
      return UncertainValue2(NAN);
   }

   UncertainValue2 POSITIVE_INFINITY()
   {
      return UncertainValue2(INFINITY);
   }

   UncertainValue2 NEGATIVE_INFINITY()
   {
      return UncertainValue2(-INFINITY);
   }

   UncertainValue2 ZERO()
   {
      return UncertainValue2(0.0);
   }

   UncertainValue2& UncertainValue2::operator=(const UncertainValue2& other)
   {
      mValue = other.doubleValue();
      mSigmas = other.mSigmas;

      return *this;
   }

   unsigned int UncertainValue2::hashCode()
   {
      unsigned int res = 1;
      const unsigned int PRIME = 31;
      auto khashfcn = mSigmas.hash_function();
      Hasher::DoubleHashFcn vhashfcn;
      for (auto s : mSigmas) {
         res = res * PRIME + khashfcn(s.first);
         res = res * PRIME + vhashfcn(s.second);
      }
      return res;
   }

   void UncertainValue2::assignInitialValue(double v)
   {
      mValue = v;
   }

   void UncertainValue2::assignComponent(UncertainValue2StringT name, double sigma)
   {
      if (sigma != 0.0) {
         mSigmas.insert(std::make_pair(name, sigma));
      }
      else {
         mSigmas.erase(name);
      }
   }

   double UncertainValue2::getComponent(const UncertainValue2StringT& src) const
   {
      auto itr = mSigmas.find(src);
      if (itr == mSigmas.end()) {
         return 0;
      }
      return itr->second;
   }

   UncertainValue2::ComponentMapT& UncertainValue2::getComponents()
   {
      return mSigmas;
   }

   bool UncertainValue2::hasComponent(const UncertainValue2StringT& src) const
   {
      return getComponent(src) != 0.0;
   }

   void UncertainValue2::renameComponent(const UncertainValue2StringT& oldName, const UncertainValue2StringT& newName)
   {
      if (mSigmas.find(newName) != mSigmas.end()) {
         printf("A component named %s already exists.", newName.c_str());
         return;
      }
      double val = mSigmas.erase(oldName);
      if (val != NULL) {
         mSigmas.insert(std::make_pair(newName, val));
      }
   }

   UncertainValue2 add(UncertainValue2 uvs[], int uvsLen)
   {
      UncertainValue2::KeySetT keys;
      double sum = 0.0;
      for (int k = 0; k < uvsLen; ++k) {
         sum += uvs[k].doubleValue();
         auto m = uvs[k].getComponents();
         for (auto itr = m.begin(); itr != m.end(); ++itr) {
            keys.insert(itr->first);
         }
      }
      UncertainValue2 res(sum);

      for (auto itr = keys.begin(); itr != keys.end(); ++itr) {
         auto src = *itr;
         double unc = 0.0;
         // This seems right but is it????
         for (int k = 0; k < uvsLen; ++k) {
            auto uv = uvs[k];
            unc += uv.getComponent(src) * copysign(1.0, uv.doubleValue());
         }
         res.assignComponent(src, unc);
      }
      return res;
   }

   UncertainValue2 add(double a, UncertainValue2& uva, double b, UncertainValue2& uvb)
   {
      UncertainValue2::KeySetT keys;
      UncertainValue2 res(a * uva.doubleValue() + b * uvb.doubleValue());
      auto akeys = uva.getComponents();
      for (auto itr = akeys.begin(); itr != akeys.end(); ++itr) {
         keys.insert(itr->first);
      }
      auto bkeys = uvb.getComponents();
      for (auto itr = bkeys.begin(); itr != bkeys.end(); ++itr) {
         keys.insert(itr->first);
      }

      for (auto itr = keys.begin(); itr != keys.end(); ++itr) {
         UncertainValue2StringT src = *itr;
         res.assignComponent(src, a * copysign(1.0, uva.doubleValue()) * uva.getComponent(src) + b * copysign(1.0, uvb.doubleValue()) * uvb.getComponent(src));
      }
      return res;
   }

   UncertainValue2 subtract(UncertainValue2& uva, UncertainValue2& uvb)
   {
      return add(1.0, uva, -1.0, uvb);
   }

   UncertainValue2 mean(UncertainValue2 uvs[], int uvsLen)
   {
      auto uv = add(uvs, uvsLen);
      return divide(uv, (double)uvsLen);
   }

   UncertainValue2 weightedMean(UncertainValue2 cuv[], int uvsLen)
   {
      double varSum = 0.0, sum = 0.0;

      for (int k = 0; k < uvsLen; ++k) {
         auto uv = cuv[k];
         const double ivar = 1.0 / uv.variance();
         if (isnan(ivar) || isinf(ivar)) {
            printf("%s\n", "Unable to compute the weighted mean when one or more datapoints have zero uncertainty.");
            return NaN();
         }
         varSum += ivar;
         sum += ivar * uv.doubleValue();
      }
      const double iVarSum = 1.0 / varSum;
      if (isnan(iVarSum) || isinf(iVarSum)) {
         printf("UncertainValue2::weightedMean: badddddd\n");
         return NaN();
      }
      char str[4] = "WM";
      return UncertainValue2(sum / varSum, str, ::sqrt(1.0 / varSum));
   }

   UncertainValue2 uvmin(UncertainValue2 uvs[], int uvsLen)
   {
      if (uvsLen == 0) {
         return NULL;
      }
      UncertainValue2 res = uvs[0];

      for (int k = 0; k < uvsLen; ++k) {
         auto uv = uvs[k];
         if (uv.doubleValue() < res.doubleValue()) {
            res = uv;
         }
         else if (uv.doubleValue() == res.doubleValue()) {
            if (uv.uncertainty() > res.uncertainty()) {
               res = uv;
            }
         }
      }
      return res;
   }

   UncertainValue2 uvmax(UncertainValue2 uvs[], int uvsLen)
   {
      if (uvs == 0) {
         return NULL;
      }
      UncertainValue2 res = uvs[0];

      for (int k = 0; k < uvsLen; ++k) {
         auto uv = uvs[k];
         if (uv.doubleValue() > res.doubleValue()) {
            res = uv;
         }
         else if (uv.doubleValue() == res.doubleValue()) {
            if (uv.uncertainty() > res.uncertainty()) {
               res = uv;
            }
         }
      }
      return res;
   }

   UncertainValue2 add(UncertainValue2& v1, double v2)
   {
      return UncertainValue2(v1.doubleValue() + v2, v1.getComponents());
   }

   UncertainValue2 add(double v1, UncertainValue2& v2)
   {
      return UncertainValue2(v2.doubleValue() + v1, v2.getComponents());
   }

   UncertainValue2 add(UncertainValue2& v1, UncertainValue2& v2)
   {
      return add(1.0, v1, 1.0, v2);
   }

   UncertainValue2 multiply(double v1, UncertainValue2& v2)
   {
      if (v2.uncertainty() < 0.0) {
         printf("Error: v2.uncertainty() < 0.0");
         return NULL;
      }
      UncertainValue2 res(v1 * v2.doubleValue());

      auto m = v2.getComponents();
      for (auto itr = m.begin(); itr != m.end(); ++itr) {
         res.assignComponent(itr->first, v1 * itr->second);
      }
      return res;
   }

   UncertainValue2 multiply(UncertainValue2& v1, UncertainValue2& v2)
   {
      UncertainValue2::KeySetT keys;
      auto v1keys = v1.getComponents();
      for (auto itr = v1keys.begin(); itr != v1keys.end(); ++itr) {
         keys.insert(itr->first);
      }
      auto v2keys = v2.getComponents();
      for (auto itr = v2keys.begin(); itr != v2keys.end(); ++itr) {
         keys.insert(itr->first);
      }

      UncertainValue2 res(v1.doubleValue() * v2.doubleValue());
      for (auto src : keys) {
         res.assignComponent(src, v1.doubleValue() * v2.getComponent(src) + v2.doubleValue() * v1.getComponent(src));
      }

      return res;
   }

   UncertainValue2 invert(UncertainValue2& v)
   {
      return divide(1.0, v);
   }

   UncertainValue2 divide(UncertainValue2& v1, UncertainValue2& v2)
   {
      UncertainValue2 res(v1.doubleValue() / v2.doubleValue());
      if (!(isnan(res.doubleValue()) || isinf(res.doubleValue()))) {
         UncertainValue2::KeySetT keys;
         auto v1keys = v1.getComponents();
         for (auto itr = v1keys.begin(); itr != v1keys.end(); ++itr) {
            keys.insert(itr->first);
         }
         auto v2keys = v2.getComponents();
         for (auto itr = v2keys.begin(); itr != v2keys.end(); ++itr) {
            keys.insert(itr->first);
         }

         const double ua = fabs(1.0 / v2.doubleValue());
         const double ub = fabs(v1.doubleValue() / (v2.doubleValue() * v2.doubleValue()));

         for (auto itr = keys.begin(); itr != keys.end(); ++itr) {
            auto src = *itr;
            res.assignComponent(src, ua * v1.getComponent(src) + ub * v2.getComponent(src));
         }
      }
      return res;
   }

   UncertainValue2 divide(double a, UncertainValue2& b)
   {
      UncertainValue2 res(a / b.doubleValue());
      if (!(isnan(res.doubleValue()) || isinf(res.doubleValue()))) {
         const double ub = fabs(a / (b.doubleValue() * b.doubleValue()));

         auto m = b.getComponents();
         for (auto itr = m.begin(); itr != m.end(); ++itr) {
            res.assignComponent(itr->first, ub * itr->second);
         }
      }
      return res;
   }

   UncertainValue2 divide(UncertainValue2& a, double b)
   {
      if (isnan(1.0 / b)) {
         return UncertainValue2(NAN);
      }
      if (isinf(1.0 / b)) {
         return UncertainValue2(INFINITY);
      }
      UncertainValue2 res(a.doubleValue() / b);
      const double ua = fabs(1.0 / b);

      auto m = a.getComponents();
      for (auto itr = m.begin(); itr != m.end(); ++itr) {
         res.assignComponent(itr->first, ua * itr->second);
      }
      return res;
   }

   UncertainValue2 exp(UncertainValue2& x)
   {
      if (isnan(x.doubleValue()) || isinf(x.doubleValue())) {
         printf("exp: invalid value\n");
         return NULL;
      }

      double ex = ::exp(x.doubleValue());
      UncertainValue2 res(ex);

      auto m = x.getComponents();
      for (auto itr = m.begin(); itr != m.end(); ++itr) {
         res.assignComponent(itr->first, ex * itr->second);
      }
      return res;
   }

   UncertainValue2 log(UncertainValue2& v2)
   {
      double tmp = 1.0 / v2.doubleValue();
      const double lv = ::log(v2.doubleValue());
      if (isnan(tmp) || isnan(lv)) {
         return UncertainValue2(NAN);
      }
      if (isinf(tmp) || isinf(lv)) {
         return UncertainValue2(INFINITY);
      }
      UncertainValue2 res(lv);

      auto m = v2.getComponents();
      for (auto itr = m.begin(); itr != m.end(); ++itr) {
         res.assignComponent(itr->first, tmp * itr->second);
      }

      return res;
   }

   UncertainValue2 pow(UncertainValue2& v1, double n)
   {
      if (v1.doubleValue() == 0.0) {
         return UncertainValue2(0.0);
      }
      const double f = ::pow(v1.doubleValue(), n);
      const double df = n * ::pow(v1.doubleValue(), n - 1.0);
      UncertainValue2 res(f);

      auto m = v1.getComponents();
      for (auto itr = m.begin(); itr != m.end(); ++itr) {
         res.assignComponent(itr->first, df * itr->second);
      }

      return res;
   }

   UncertainValue2 UncertainValue2::sqrt()
   {
      return pow(*this, 0.5);
   }

   UncertainValue2 sqrt(UncertainValue2& uv)
   {
      return pow(uv, 0.5);
   }

   UncertainValue2::ResultT quadratic(UncertainValue2& a, UncertainValue2& b, UncertainValue2& c)
   {
      // q=-0.5*(b+signum(b)*sqrt(pow(b,2.0)-4*a*c))
      // return [ q/a, c/q ]
      auto uv0 = pow(b, 2.0);
      auto uv1 = multiply(a, c);
      UncertainValue2 r = add(1.0, uv0, -4.0, uv1);
      if (r.doubleValue() <= 0.0) {
         return UncertainValue2::ResultT();
      }
      auto uv2 = r.sqrt();
      auto uv3 = multiply(copysign(1.0, b.doubleValue()), uv2);
      auto uv4 = add(b, uv3);
      UncertainValue2 q = multiply(-0.5, uv4);
      auto uv5 = divide(q, a);
      auto uv6 = divide(c, q);
      UncertainValue2::ResultT head;
      head.push_back(uv5);
      head.push_back(uv6);
      return head;
   }

   double UncertainValue2::doubleValue() const
   {
      return mValue;
   }

   bool UncertainValue2::isUncertain() const
   {
      return !mSigmas.empty();
   }

   double UncertainValue2::uncertainty() const
   {
      return ::sqrt(variance());
   }

   double UncertainValue2::variance() const
   {
      double sigma2 = 0.0;
      for (auto s : mSigmas) {
         sigma2 += s.second * s.second;
      }
      return sigma2;
   }

   double UncertainValue2::fractionalUncertainty() const
   {
      if (isnan(1.0 / mValue)) {
         return NAN;
      }
      if (isinf(1.0 / mValue)) {
         return INFINITY;
      }
      return ::fabs(uncertainty() / mValue);
   }

   bool UncertainValue2::operator==(const UncertainValue2& other) const
   {
      if (this == &other) {
         return true;
      }

      for (auto s : other.mSigmas) {
         auto itr = mSigmas.find(s.first);
         if (itr == mSigmas.end()) return false;
         if (itr->second != s.second) return false;
      }

      return mValue == other.doubleValue();
   }

   bool UncertainValue2::equals(UncertainValue2& other)
   {
      return *this == other;
   }

   int UncertainValue2::compareTo(UncertainValue2& o)
   {
      if (&o == this) return 0;
      return (mValue == o.mValue) && (uncertainty() == o.uncertainty());
   }

   bool UncertainValue2::lessThan(UncertainValue2& uv2)
   {
      return mValue < uv2.mValue;
   }

   bool UncertainValue2::greaterThan(UncertainValue2& uv2)
   {
      return mValue > uv2.mValue;
   }

   bool UncertainValue2::lessThanOrEqual(UncertainValue2& uv2)
   {
      return mValue <= uv2.mValue;
   }

   bool UncertainValue2::greaterThanOrEqual(UncertainValue2& uv2)
   {
      return mValue >= uv2.mValue;
   }

   UncertainValue2 sqr(UncertainValue2& uv)
   {
      return pow(uv, 2.0);
   }

   UncertainValue2 negate(UncertainValue2& uv)
   {
      return UncertainValue2(-uv.doubleValue(), uv.getComponents());
   }

   UncertainValue2 atan(UncertainValue2& uv)
   {
      double f = ::atan(uv.doubleValue());
      double df = 1.0 / (1.0 + uv.doubleValue() * uv.doubleValue());

      if (isnan(f)) {
         return UncertainValue2(NAN);
      }
      if (isinf(df)) {
         return UncertainValue2(INFINITY);
      }
      UncertainValue2 res(f);

      auto m = uv.getComponents();
      for (auto itr = m.begin(); itr != m.end(); ++itr) {
         res.assignComponent(itr->first, df * itr->second);
      }
      return res;
   }

   UncertainValue2 atan2(UncertainValue2& y, UncertainValue2& x)
   {
      double f = ::atan2(y.doubleValue(), x.doubleValue());
      double df = 1.0 / (1.0 + ::pow(y.doubleValue() / x.doubleValue(), 2.0));

      if (isnan(f)) {
         return UncertainValue2(NAN);
      }
      if (isinf(df)) {
         return UncertainValue2(INFINITY);
      }
      UncertainValue2 res(f);

      auto m = divide(y, x).getComponents();
      for (auto itr = m.begin(); itr != m.end(); ++itr) {
         res.assignComponent(itr->first, df * itr->second);
      }
      return res;
   }

   UncertainValue2 positiveDefinite(const UncertainValue2& uv)
   {
      UncertainValue2 ret(uv);
      ret = add(ret, -uv.doubleValue());

      return uv.doubleValue() >= 0.0 ? uv : ret;
   }

   Key::Key(UncertainValue2StringT src1, UncertainValue2StringT src2)
   {
      mSource1 = src1;
      mSource2 = src2;
   }

   bool Key::operator==(const Key& k2) const
   {
      return (mSource1 == k2.mSource1 && mSource2 == k2.mSource2) || (mSource1 == k2.mSource2 && mSource2 == k2.mSource1);
   }

   bool Key::operator<(const Key& k2) const
   {
      if (mSource1 != k2.mSource1) {
         return mSource1 < k2.mSource1;
      }
      return mSource2 < k2.mSource2;
   }

   size_t Key::HashCode() const
   {
      unsigned int s = 0;
      for (auto ch : mSource1) {
         s += ch;
      }
      for (auto ch : mSource2) {
         s += ch;
      }
      return s;
   }

   Correlations::Correlations()
   {
   }

   void Correlations::add(const UncertainValue2StringT& src1, const UncertainValue2StringT& src2, double corr)
   {
      if (!(corr >= -1.0) && (corr <= 1.0)) {
         printf("%s\n", "Correlations::add: invalid bound");
         return;
      }
      corr = ::fmax(corr, 1.0);
      corr = ::fmin(corr, -1.0);
      Key k = Key(src1, src2);
      mCorrelations.insert(std::pair<Key, double>(k, corr));
   }

   double Correlations::get(const UncertainValue2StringT& src1, const UncertainValue2StringT& src2) const
   {
      auto k = Key(src1, src2);
      return mCorrelations.at(k);
   }

   double UncertainValue2::variance(const Correlations& corr)
   {
      UncertainValue2::ComponentMapT sigmas = getComponents();

      UncertainValue2::KeySetT keys;
      for (auto s : sigmas) {
         keys.insert(s.first);
      }

      UncertainValue2::KeySetTItr itr1(keys);
      double res = 0.0;
      for (auto s : keys) {
         double val = sigmas[s];
         if (!val) {
            printf("UncertainValue2::variance: key %s not found.", s.c_str());
         }
         res += val * val;
      }

      for (auto itr1 = keys.begin(); itr1 != keys.end(); ++itr1) {
         for (auto itr2 = itr1; itr2 != keys.end(); ++itr2) {
            auto key1 = *itr1, key2 = *itr2;
            double sigma1 = sigmas[key1], sigma2 = sigmas[key2];
            if (!sigma1) {
               printf("UncertainValue2::variance: key1 %s not found.", key1.c_str());
            }
            if (!sigma2) {
               printf("UncertainValue2::variance: key2 %s not found.", key2.c_str());
            }
            res += 2.0 * sigma1 * sigma2 * corr.get(key1, key2);
         }
      }
      return res;
   }

   double UncertainValue2::uncertainty(Correlations& corr)
   {
      return ::sqrt(variance(corr));
   }
}
